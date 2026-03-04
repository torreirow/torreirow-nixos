#!/usr/bin/env bash
# Test script voor Wayland app compatibility na de fixes
# Run dit na uitloggen/inloggen

echo "=== Environment Variables Check ==="
echo "QT_QPA_PLATFORM=$QT_QPA_PLATFORM (moet zijn: wayland;xcb)"
echo "GDK_BACKEND=$GDK_BACKEND (moet zijn: x11,wayland)"
echo "SDL_VIDEODRIVER=$SDL_VIDEODRIVER (moet zijn: wayland,x11)"
echo "MOZ_ENABLE_WAYLAND=$MOZ_ENABLE_WAYLAND (moet zijn: 1)"
echo ""
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
echo ""

if [[ "$QT_QPA_PLATFORM" != "wayland;xcb" ]]; then
    echo "❌ QT_QPA_PLATFORM is niet correct - heb je uitgelogd en weer ingelogd?"
    exit 1
fi

echo "✅ Environment variables zijn correct!"
echo ""
echo "=== Test Apps (sluit elk venster handmatig) ==="
echo ""

echo "Testing OnlyOffice..."
timeout 5 onlyoffice-desktopeditors &
pid=$!
sleep 3
if ps -p $pid > /dev/null 2>&1; then
    echo "✅ OnlyOffice is gestart (sluit het venster als het verschijnt)"
else
    echo "❌ OnlyOffice start niet"
fi
echo ""

echo "Testing SubtitleEdit..."
timeout 5 subtitleedit &
pid=$!
sleep 3
if ps -p $pid > /dev/null 2>&1; then
    echo "✅ SubtitleEdit is gestart (sluit het venster als het verschijnt)"
else
    echo "❌ SubtitleEdit start niet"
fi
echo ""

echo "Testing Clementine..."
timeout 5 clementine &
pid=$!
sleep 3
if ps -p $pid > /dev/null 2>&1; then
    echo "✅ Clementine is gestart (sluit het venster als het verschijnt)"
else
    echo "❌ Clementine start niet"
fi
echo ""

echo "=== Klaar met testen ==="
echo "Als apps draaien maar geen venster tonen, rapport dit aan Claude."
echo ""
echo "Om dit gesprek te hervatten, open gewoon Claude Code weer."
