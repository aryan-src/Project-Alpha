#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f "$DIR/HandTracker.app/Contents/MacOS/HandTracker" ]; then
    echo "🔨 App not built yet — running build first..."
    "$DIR/build_and_run.sh" --run
else
    echo "🚀 Launching HandTracker..."
    open "$DIR/HandTracker.app"
fi
