#!/bin/bash

set -euo pipefail

usage() {
    echo "Usage: $0 {ai|gpu}"
    echo "  ai   - Patch AI chat files into system config"
    echo "  gpu  - Patch GPU monitoring files into system config"
    exit 1
}

patch_ai() {
    cp -i ./dots/.config/quickshell/ii/services/Ai.qml \
       ~/.config/quickshell/ii/services/Ai.qml

    cp -i ./dots/.config/quickshell/ii/services/ai/AiMessageData.qml \
       ~/.config/quickshell/ii/services/ai/AiMessageData.qml

    cp -i ./dots/.config/quickshell/ii/services/ai/OpenAiApiStrategy.qml \
       ~/.config/quickshell/ii/services/ai/OpenAiApiStrategy.qml

    cp -i ./dots/.config/quickshell/ii/services/ai/MistralApiStrategy.qml \
       ~/.config/quickshell/ii/services/ai/MistralApiStrategy.qml

    cp -i ./dots/.config/quickshell/ii/modules/ii/sidebarLeft/AiChat.qml \
       ~/.config/quickshell/ii/modules/ii/sidebarLeft/AiChat.qml

    cp -i -- ./dots/.config/quickshell/ii/translations/*.json \
        ~/.config/quickshell/ii/translations/
}

patch_gpu() {
    cp -i ./dots/.config/quickshell/ii/services/ResourceUsage.qml \
       ~/.config/quickshell/ii/services/ResourceUsage.qml

    cp -i ./dots/.config/quickshell/ii/modules/common/Config.qml \
       ~/.config/quickshell/ii/modules/common/Config.qml

    cp -i ./dots/.config/quickshell/ii/modules/ii/bar/Resources.qml \
       ~/.config/quickshell/ii/modules/ii/bar/Resources.qml

    cp -i ./dots/.config/quickshell/ii/modules/ii/bar/ResourcesPopup.qml \
       ~/.config/quickshell/ii/modules/ii/bar/ResourcesPopup.qml

    cp -i ./dots/.config/quickshell/ii/modules/ii/verticalBar/Resources.qml \
       ~/.config/quickshell/ii/modules/ii/verticalBar/Resources.qml
}

case "${1:-}" in
    ai)  patch_ai ;;
    gpu) patch_gpu ;;
    *)   usage ;;
esac
