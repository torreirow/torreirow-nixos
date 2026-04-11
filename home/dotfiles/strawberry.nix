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
    -- Create or update Radio Streams playlist
    INSERT OR IGNORE INTO playlists (name, ui_order, is_favorite) VALUES ('Radio Streams', 0, 1);

    -- Clear existing items from Radio Streams playlist
    DELETE FROM playlist_items WHERE playlist = (SELECT ROWID FROM playlists WHERE name = 'Radio Streams' LIMIT 1);

    -- Insert radio streams
  '' + lib.concatImapStrings generatePlaylistItemSQL radioStreams;

  # Script that updates the Strawberry database
  updateStreamsScript = pkgs.writeShellScript "update-strawberry-streams.sh" ''
    DB_DIR="$HOME/.local/share/strawberry/strawberry"
    DB_FILE="$DB_DIR/strawberry.db"

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
