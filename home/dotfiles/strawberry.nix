{ config, lib, pkgs, ... }:

let
  # Import radio streams list
  radioStreams = import ./strawberry-radio-streams.nix;

  # Generate SQL statements to insert streams into a playlist
  # Using type=4 for stream URLs
  generatePlaylistItemSQL = idx: stream:
    let
      thumbnail = if stream ? thumbnail then "'${stream.thumbnail}'" else "NULL";
    in ''
    INSERT INTO playlist_items (playlist, type, url, title, art_manual)
    VALUES (
      (SELECT ROWID FROM playlists WHERE name = 'Radio Streams' LIMIT 1),
      4,
      '${stream.url}',
      '${stream.name}',
      ${thumbnail}
    );
  '';

  # Combine all SQL statements
  sqlStatements = ''
    -- Remove duplicate Radio Streams playlists, keep only the lowest ROWID
    DELETE FROM playlist_items WHERE playlist IN (
      SELECT ROWID FROM playlists WHERE name = 'Radio Streams'
        AND ROWID != (SELECT MIN(ROWID) FROM playlists WHERE name = 'Radio Streams')
    );
    DELETE FROM playlists WHERE name = 'Radio Streams'
      AND ROWID != (SELECT MIN(ROWID) FROM playlists WHERE name = 'Radio Streams');

    -- Create playlist if it doesn't exist yet
    INSERT INTO playlists (name, ui_order, is_favorite)
      SELECT 'Radio Streams', 0, 1 WHERE NOT EXISTS (
        SELECT 1 FROM playlists WHERE name = 'Radio Streams'
      );

    -- Ensure it is marked as favorite
    UPDATE playlists SET is_favorite=1, ui_order=0 WHERE name = 'Radio Streams';

    -- Clear existing items and re-insert
    DELETE FROM playlist_items WHERE playlist = (SELECT MIN(ROWID) FROM playlists WHERE name = 'Radio Streams');

    -- Insert radio streams
  '' + lib.concatImapStrings generatePlaylistItemSQL radioStreams;

  # Script that updates the Strawberry database
  updateStreamsScript = pkgs.writeShellScript "update-strawberry-streams.sh" ''
    DB_DIR="$HOME/.local/share/strawberry/strawberry"
    DB_FILE="$DB_DIR/strawberry.db"
    CONF_FILE="$HOME/.config/strawberry/strawberry.conf"

    # Force HTTP/2 for streaming. With http2=false Strawberry sets SOUP_FORCE_HTTP1,
    # Cloudflare then sends small chunked blocks and icydemux typefinds the first
    # few hundred bytes of an AAC stream (Bright FM) as video/x-cdg -> "not-linked".
    # Only this one key is set; Strawberry keeps managing the rest of the file.
    mkdir -p "$(dirname "$CONF_FILE")"
    ${pkgs.crudini}/bin/crudini --set "$CONF_FILE" Backend http2 true

    # Create directory if it doesn't exist
    mkdir -p "$DB_DIR"

    # Wait for Strawberry database to exist
    if [ ! -f "$DB_FILE" ]; then
      echo "Strawberry database doesn't exist yet, skipping radio streams setup"
      echo "Start Strawberry once to create the database, then run home-manager switch again"
      exit 0
    fi

    # Update radio streams playlist
    echo "Updating Radio Streams playlist..."
    ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" <<EOF
    ${sqlStatements}
    EOF

    echo "Radio Streams playlist updated successfully"
  '';

in {
  # Run the update script on every home-manager activation
  home.activation.updateStrawberryStreams = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${updateStreamsScript}
  '';
}
