#ifndef TMUXCONTROLLER_H
#define TMUXCONTROLLER_H

#include <QObject>
#include <QString>
#include <QStringList>

class TmuxController : public QObject
{
    Q_OBJECT

public:
    explicit TmuxController(QObject *parent = nullptr);

    Q_INVOKABLE bool isAvailable() const;
    Q_INVOKABLE bool splitPane(const QString &session, bool horizontal) const;
    Q_INVOKABLE bool joinPane(const QString &targetSession, const QString &sourceSession,
                              bool horizontal) const;
    Q_INVOKABLE bool killSession(const QString &session) const;
    Q_INVOKABLE bool hasActiveProcess(const QString &session) const;

private:
    static QStringList listPanes(const QString &session);
    static bool runTmux(const QStringList &arguments, int timeoutMs,
                        QString *standardOutput = nullptr);
};

#endif // TMUXCONTROLLER_H
