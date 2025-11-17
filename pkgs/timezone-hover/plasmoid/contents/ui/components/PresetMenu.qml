import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

// Menu for timezone presets
QQC2.Menu {
    id: presetMenu

    // Property to access timezone defaults
    property var tzDefaults

    signal presetSelected(string presetName)

    QQC2.MenuItem {
        text: i18n("Chicago, UK, Perth")
        onClicked: presetMenu.presetSelected("chicago-uk-perth")
    }

    QQC2.MenuItem {
        text: i18n("Global Business")
        onClicked: presetMenu.presetSelected("global-business")
    }

    QQC2.MenuItem {
        text: i18n("Europe Focused")
        onClicked: presetMenu.presetSelected("europe-focused")
    }

    QQC2.MenuItem {
        text: i18n("Americas")
        onClicked: presetMenu.presetSelected("americas")
    }

    QQC2.MenuItem {
        text: i18n("Asia Pacific")
        onClicked: presetMenu.presetSelected("asia-pacific")
    }
}
