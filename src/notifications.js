const NOTIFIER_URL = process.env.NOTIFIER_URL;

// Fire-and-forget notification to the email notifier service. Notifications are
// best-effort: a notifier outage must never fail the todo operation itself.
async function notify(event, item) {
    if (!NOTIFIER_URL) return;

    try {
        const res = await fetch(`${NOTIFIER_URL}/notify`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ event, item }),
        });

        if (!res.ok) {
            console.error(
                `Notifier responded with ${res.status} for event ${event}`,
            );
        }
    } catch (err) {
        console.error(`Failed to send ${event} notification`, err.message);
    }
}

module.exports = { notify };
