/*******************************************************************************
* Copyright (c) 2013-2021 "Filippo Scognamiglio"
* https://github.com/Swordfish90/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models
import org.kde.kirigami as Kirigami

Item {
    id: tabsRoot

    readonly property int innerPadding: 6
    readonly property string currentTitle: {
        var title = currentIndex >= 0 ? tabsModel.get(currentIndex).title : ""
        return normalizeTitle(title) || "cool-retro-term"
    }
    property alias currentIndex: tabBar.currentIndex
    readonly property int count: tabsModel.count
    property size terminalSize: Qt.size(0, 0)
    property int pendingCloseIndex: -1
    property int tmuxSessionCounter: 0
    property int mergeSourceIndex: -1
    property bool mergeHorizontal: true
    readonly property bool tmuxAvailable: tmuxController.isAvailable()
    readonly property bool canMergeTabs: tmuxAvailable && count > 1

    function normalizeTitle(rawTitle) {
        if (rawTitle === undefined || rawTitle === null) {
            return ""
        }
        return String(rawTitle).trim()
    }

    function addTab() {
        tmuxSessionCounter += 1
        var sessionName = "crt-" + Date.now() + "-" + tmuxSessionCounter
        tabsModel.append({ title: "", tmuxSession: sessionName })
        tabBar.currentIndex = tabsModel.count - 1
    }

    function closeTab(index) {
        if (tabsModel.count <= 1) {
            terminalWindow.close()
            return
        }

        if (tabHasActiveProcess(index)) {
            pendingCloseIndex = index
            closeTabDialog.open()
            return
        }

        removeTab(index)
    }

    function removeTab(index) {
        var current = tabBar.currentIndex
        tabsModel.remove(index)
        if (index < current)
            current -= 1
        tabBar.currentIndex = Math.min(current, tabsModel.count - 1)
    }

    function closeCurrentTab() {
        removeTab(currentIndex)
    }

    function tabHasActiveProcess(index) {
        if (index < 0 || index >= stack.children.length)
            return false
        var item = stack.children[index]
        return item && item.hasActiveProcess ? item.hasActiveProcess() : false
    }

    function anyTabHasActiveProcess() {
        for (var i = 0; i < stack.children.length; i++) {
            if (tabHasActiveProcess(i))
                return true
        }
        return false
    }

    function shouldConfirmWindowClose() {
        return count > 1 || anyTabHasActiveProcess()
    }

    function splitActivePane(horizontal) {
        if (currentIndex < 0 || currentIndex >= stack.children.length)
            return
        var item = stack.children[currentIndex]
        if (item && item.splitPane)
            item.splitPane(horizontal)
        forceActiveFocusCurrentTab()
    }

    function openMergeDialog() {
        mergeCandidates.clear()
        for (var i = 0; i < tabsModel.count; i++) {
            if (i === currentIndex)
                continue
            var title = normalizeTitle(tabsModel.get(i).title)
            mergeCandidates.append({
                tabIndex: i,
                title: title || qsTr("Tab %1").arg(i + 1)
            })
        }
        mergeSourceIndex = mergeCandidates.count > 0 ? mergeCandidates.get(0).tabIndex : -1
        mergeHorizontal = true
        sideBySideRadio.checked = true
        stackedRadio.checked = false
        mergeError.text = ""
        mergeTabDialog.open()
    }

    function mergeTab(sourceIndex, horizontal) {
        if (sourceIndex < 0 || sourceIndex >= stack.children.length || sourceIndex === currentIndex)
            return false

        var target = stack.children[currentIndex]
        var source = stack.children[sourceIndex]
        if (!target || !source || !target.usesTmux || !source.usesTmux)
            return false
        if (target.tmuxSessionName === "" || source.tmuxSessionName === "")
            return false

        var merged = tmuxController.joinPane(target.tmuxSessionName,
                                             source.tmuxSessionName, horizontal)
        if (merged)
            forceActiveFocusCurrentTab()
        return merged
    }

    function mergeSelectedTab() {
        if (mergeSourceIndex < 0)
            return
        if (mergeTab(mergeSourceIndex, mergeHorizontal)) {
            mergeTabDialog.close()
        } else {
            mergeError.text = qsTr("Could not merge the selected tab. Its processes may still be running in the original tab.")
        }
    }

    ListModel {
        id: tabsModel
    }

    ListModel {
        id: mergeCandidates
    }

    function forceActiveFocusCurrentTab() {
        if (currentIndex >= 0 && currentIndex < stack.children.length) {
            var item = stack.children[currentIndex]
            if (item && item.activate) {
                item.activate()
            }
        }
    }

    Component.onCompleted: addTab()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: tabRow
            Layout.fillWidth: true
            height: rowLayout.implicitHeight
            color: palette.window
            visible: tabsModel.count > 1

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                spacing: 0

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focusPolicy: Qt.NoFocus

                    Repeater {
                        model: tabsModel
                        TabButton {
                            id: tabButton
                            implicitWidth: Math.max(200, tabText.implicitWidth + 52)
                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors { leftMargin: innerPadding; rightMargin: innerPadding }
                                spacing: innerPadding

                                Label {
                                    id: tabText
                                    text: model.title || qsTr("Tab %1").arg(index + 1)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignLeft
                                    wrapMode: Text.NoWrap
                                    maximumLineCount: 1
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ToolButton {
                                    icon.name: "tab-close"
                                    display: AbstractButton.IconOnly
                                    focusPolicy: Qt.NoFocus
                                    padding: innerPadding
                                    Layout.alignment: Qt.AlignVCenter
                                    onClicked: tabsRoot.closeTab(index)
                                }
                            }
                        }
                    }
                }

                ToolButton {
                    id: splitHorizontalButton
                    text: "||"
                    visible: tabsRoot.tmuxAvailable
                    enabled: tabsRoot.count > 0
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter

                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Split vertically (side by side) - tmux: Ctrl+b %")

                    onClicked: tabsRoot.splitActivePane(true)
                }

                ToolButton {
                    id: splitVerticalButton
                    text: "="
                    visible: tabsRoot.tmuxAvailable
                    enabled: tabsRoot.count > 0
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter

                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Split horizontally (stacked) - tmux: Ctrl+b \"")

                    onClicked: tabsRoot.splitActivePane(false)
                }

                ToolButton {
                    id: mergeTabButton
                    text: "\u21c4"
                    visible: tabsRoot.canMergeTabs
                    enabled: tabsRoot.canMergeTabs
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter

                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Merge another tab into this one (processes keep running)")

                    onClicked: tabsRoot.openMergeDialog()
                }

                ToolButton {
                    id: addTabButton
                    text: "+"
                    focusPolicy: Qt.NoFocus
                    Layout.fillHeight: true
                    padding: innerPadding
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: tabsRoot.addTab()
                }
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            Repeater {
                model: tabsModel
                TerminalContainer {
                    property bool shouldHaveFocus: terminalWindow.active && StackLayout.isCurrentItem
                    isActive: StackLayout.isCurrentItem
                    tmuxSessionName: model.tmuxSession
                    onShouldHaveFocusChanged: {
                        if (shouldHaveFocus) {
                            activate()
                        }
                    }
                    onTitleChanged: tabsModel.setProperty(index, "title", normalizeTitle(title))
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    onSessionFinished: tabsRoot.closeTab(index)
                    onTerminalSizeChanged: updateTerminalSize()

                    function updateTerminalSize() {
                        // Every tab will have the same size so we can simply take the first one.
                        if (index == 0) {
                            tabsRoot.terminalSize = terminalSize
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: closeTabDialog

        anchors.centerIn: parent
        modal: true
        title: qsTr("  Close tab?")
        width: 380
        contentWidth: availableWidth

        onClosed: tabsRoot.pendingCloseIndex = -1

        header: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: closeTabDialog.title
                    elide: Text.ElideRight
                    font.bold: true
                }

                ToolButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    text: qsTr("Close")
                    icon.name: "tab-close"
                    display: AbstractButton.IconOnly
                    onClicked: closeTabDialog.reject()
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("A process is still running in this tab. Close it anyway?")
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 6

                Button {
                    text: qsTr("Close")
                    onClicked: {
                        var index = tabsRoot.pendingCloseIndex
                        closeTabDialog.close()
                        if (index >= 0)
                            tabsRoot.removeTab(index)
                    }
                }
                Button {
                    text: qsTr("Cancel")
                    onClicked: closeTabDialog.close()
                }
            }
        }
    }

    Dialog {
        id: mergeTabDialog

        anchors.centerIn: parent
        modal: true
        title: qsTr("  Merge tab")
        width: 460
        contentWidth: availableWidth

        header: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: mergeTabDialog.title
                    elide: Text.ElideRight
                    font.bold: true
                }

                ToolButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    text: qsTr("Close")
                    icon.name: "tab-close"
                    display: AbstractButton.IconOnly
                    onClicked: mergeTabDialog.reject()
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }
        }

        contentItem: ColumnLayout {
            spacing: 12

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: qsTr("Choose the tab to move into the current one. Both tabs keep their running processes.")
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(220, contentHeight)
                clip: true
                model: mergeCandidates

                delegate: ItemDelegate {
                    width: ListView.view.width
                    text: model.title
                    highlighted: model.tabIndex === tabsRoot.mergeSourceIndex
                    onClicked: tabsRoot.mergeSourceIndex = model.tabIndex
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Direction")
                font.bold: true
            }

            ButtonGroup {
                id: mergeDirectionGroup
            }

            RadioButton {
                id: sideBySideRadio
                text: qsTr("Side by side (Ctrl+b %)")
                ButtonGroup.group: mergeDirectionGroup
                onClicked: tabsRoot.mergeHorizontal = true
            }

            RadioButton {
                id: stackedRadio
                text: qsTr("Stacked (Ctrl+b \")")
                ButtonGroup.group: mergeDirectionGroup
                onClicked: tabsRoot.mergeHorizontal = false
            }

            Label {
                id: mergeError
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Kirigami.Theme.negativeTextColor
                visible: text !== ""
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 6

                Button {
                    text: qsTr("Merge")
                    enabled: tabsRoot.mergeSourceIndex >= 0
                    onClicked: tabsRoot.mergeSelectedTab()
                }
                Button {
                    text: qsTr("Cancel")
                    onClicked: mergeTabDialog.close()
                }
            }
        }
    }
}
