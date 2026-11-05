{ runCommand, perl, immich }:

# Immich met één wijziging: bij VAAPI + software-decode komt `format=nv12` vóór `hwupload`.
# Zonder schaling (bron ≤ 720p, of een bron die de GPU niet kan decoderen) zet Immich anders
# een yuv420p-frame onomgezet op de GPU, en weigeren iHD én i965 dat bij het encoderen
# ("internal encoding error"). Zie docs/immich.md, OpenSpec immich-vaapi.
#
# Geen herbouw vanaf de bron (pnpm/vite, zwaar op de J3455) maar een kopie met één aangepast
# bestand. Een symlink-boom werkt niet: node lost ESM-imports op via het echte pad en zou dan
# het oude media.js laden. Daarom een volledige kopie waarin het oude store-pad wordt omgezet.
#
# Na een Immich-upgrade faalt de build als de patchplek niet precies één keer wordt gevonden;
# dan nagaan of upstream het zelf heeft opgelost en deze patch weghalen.

runCommand "${immich.name}-vaapi-nv12"
  {
    inherit (immich) meta;
    nativeBuildInputs = [ perl ];
    passthru = immich.passthru // { unpatched = immich; };
  }
  ''
    cp -a ${immich} $out
    chmod -R u+w $out

    # Verwijzingen naar het oude pad (wrappers, symlinks) naar de kopie laten wijzen.
    grep -rlF --null ${immich} $out | xargs -0 -r sed -i "s|${immich}|$out|g"
    find $out -type l | while read -r l; do
      t=$(readlink "$l")
      case "$t" in ${immich}*) ln -sfn "$out''${t#${immich}}" "$l" ;; esac
    done

    # Alleen de VAAPI-variant (gevolgd door scale_vaapi); QSV heeft dezelfde hwupload-regel.
    media=$out/lib/node_modules/immich/dist/utils/media.js
    perl -0pi -e \
      "s/options\.push\('hwupload=extra_hw_frames=64'\);(\s*if \(this\.shouldScale\(videoStream\)\) \{\s*options\.push\(\`scale_vaapi=)/options.push('format=nv12', 'hwupload=extra_hw_frames=64');\1/g" \
      $media
    n=$(grep -c "options.push('format=nv12', 'hwupload=extra_hw_frames=64');" $media || true)
    if [ "$n" != 1 ]; then
      echo "patchplek in media.js niet (precies één keer) gevonden: $n; Immich-code veranderd?"
      exit 1
    fi

    if grep -rqF ${immich} $out; then
      echo "verwijzing naar het ongepatchte pakket over:"; grep -rlF ${immich} $out | head
      exit 1
    fi
  ''
