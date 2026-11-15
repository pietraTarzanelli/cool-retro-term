#include "tmuxcontroller.h"

#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>

TmuxController::TmuxController(QObject *parent)
    : QObject(parent)
{
}

bool TmuxController::isAvailable() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("tmux")).isEmpty();
}

bool TmuxController::runTmux(const QStringList &arguments, int timeoutMs,
                             QString *standardOutput)
{
    QProcess process;
    process.start(QStringLiteral("tmux"), arguments);
    if (!process.waitForStarted(timeoutMs))
        return false;

    if (!process.waitForFinished(timeoutMs)) {
        process.kill();
        process.waitForFinished(timeoutMs);
        return false;
    }

    if (standardOutput)
        *standardOutput = QString::fromLocal8Bit(process.readAllStandardOutput());

    return process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
}

bool TmuxController::splitPane(const QString &session, bool horizontal) const
{
    if (session.isEmpty())
        return false;

    return runTmux(QStringList()
                   << QStringLiteral("split-window")
                   << (horizontal ? QStringLiteral("-h") : QStringLiteral("-v"))
                   << QStringLiteral("-t") << session,
                   2000);
}

QStringList TmuxController::listPanes(const QString &session)
{
    QString output;
    if (!runTmux(QStringList()
                 << QStringLiteral("list-panes")
                 << QStringLiteral("-t") << session
                 << QStringLiteral("-F") << QStringLiteral("#{pane_id}"),
                 1000, &output)) {
        return QStringList();
    }

    QStringList panes;
    const QStringList lines = output.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (!trimmed.isEmpty())
            panes.append(trimmed);
    }
    return panes;
}

bool TmuxController::joinPane(const QString &targetSession, const QString &sourceSession,
                              bool horizontal) const
{
    if (targetSession.isEmpty() || sourceSession.isEmpty() || targetSession == sourceSession)
        return false;

    const QStringList panes = listPanes(sourceSession);
    if (panes.isEmpty())
        return false;

    for (const QString &pane : panes) {
        const bool joined = runTmux(QStringList()
                                    << QStringLiteral("join-pane")
                                    << (horizontal ? QStringLiteral("-h") : QStringLiteral("-v"))
                                    << QStringLiteral("-s") << pane
                                    << QStringLiteral("-t") << targetSession,
                                    3000);
        if (!joined)
            return false;
    }

    return true;
}

bool TmuxController::killSession(const QString &session) const
{
    if (session.isEmpty())
        return true;

    return runTmux(QStringList()
                   << QStringLiteral("kill-session")
                   << QStringLiteral("-t") << session,
                   1000);
}

bool TmuxController::hasActiveProcess(const QString &session) const
{
    if (session.isEmpty())
        return false;

    QString panesOutput;
    if (!runTmux(QStringList()
                 << QStringLiteral("list-panes")
                 << QStringLiteral("-t") << session
                 << QStringLiteral("-F") << QStringLiteral("#{pane_current_command}"),
                 1000, &panesOutput)) {
        return false;
    }

    QString defaultShell;
    if (runTmux(QStringList()
                << QStringLiteral("show-options")
                << QStringLiteral("-gv") << QStringLiteral("default-shell"),
                500, &defaultShell)) {
        defaultShell = defaultShell.trimmed();
    }

    QString shellName = QFileInfo(defaultShell).fileName();
    if (shellName.isEmpty())
        shellName = QFileInfo(qEnvironmentVariable("SHELL")).fileName();

    const QStringList commands = panesOutput.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &command : commands) {
        const QString name = command.trimmed();
        if (name.isEmpty())
            continue;
        if (name == QLatin1String("tmux"))
            continue;
        if (!shellName.isEmpty() && (name == shellName || name.endsWith(QLatin1Char('/') + shellName)))
            continue;
        return true;
    }

    return false;
}
