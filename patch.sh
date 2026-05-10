#!/bin/bash

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
