{ config, lib, pkgs, ... }:

let
  # Import radio streams list
  radioStreams = import ./strawberry-radio-streams.nix;

  # Generate SQL statements to insert/update streams
  generateStreamSQL = stream: ''
    DELETE FROM radio_channels WHERE name = '${stream.name}' AND source = 0;
    INSERT INTO radio_channels (source, name, url) VALUES (0, '${stream.name}', '${stream.url}');
  '';

  # Combine all SQL statements
  sqlStatements = lib.concatMapStrings generateStreamSQL radioStreams;

  # Script that updates the Strawberry database
  updateStreamsScript = pkgs.writeShellScript "update-strawberry-streams.sh" ''
    DB_DIR="$HOME/.local/share/strawberry/strawberry"
    DB_FILE="$DB_DIR/strawberry.db"

    # Create directory if it doesn't exist
    mkdir -p "$DB_DIR"

    # Create database and table if they don't exist
    if [ ! -f "$DB_FILE" ]; then
      echo "Creating Strawberry database..."
      ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" <<EOF
    CREATE TABLE IF NOT EXISTS radio_channels (
      source INTEGER NOT NULL DEFAULT 0,
      name TEXT,
      url TEXT NOT NULL,
      thumbnail_url TEXT
    );
    EOF
    fi

    # Update radio streams
    echo "Updating Strawberry radio streams..."
    ${pkgs.sqlite}/bin/sqlite3 "$DB_FILE" <<EOF
    ${sqlStatements}
    EOF

    echo "Strawberry radio streams updated successfully"
  '';

in {
  # Run the update script on every home-manager activation
  home.activation.updateStrawberryStreams = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${updateStreamsScript}
  '';
}
