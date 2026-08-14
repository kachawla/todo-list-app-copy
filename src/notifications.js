const { EmailClient } = require('@azure/communication-email');

const {
    COMMUNICATION_SERVICES_CONNECTION_STRING: CONNECTION_STRING,
    NOTIFY_FROM,
    NOTIFY_TO,
} = process.env;

const SUBJECTS = {
    created: 'Todo item created',
    updated: 'Todo item updated',
    deleted: 'Todo item deleted',
};

// Email is only configured when the Azure Communication Services connection is
// present, so local runs and tests stay offline.
const client =
    CONNECTION_STRING && NOTIFY_FROM && NOTIFY_TO
        ? new EmailClient(CONNECTION_STRING)
        : undefined;

function describe(event, item) {
    const name = item && item.name ? item.name : item && item.id;
    const completed =
        item && typeof item.completed === 'boolean'
            ? `\nCompleted: ${item.completed}`
            : '';

    return `A todo item was ${event}.\n\nItem: ${name}\nId: ${
        item ? item.id : 'unknown'
    }${completed}`;
}

// Notifications are best-effort: a mail failure must never fail the todo
// operation that triggered it.
async function notify(event, item) {
    if (!client || !SUBJECTS[event]) return;

    try {
        const poller = await client.beginSend({
            senderAddress: NOTIFY_FROM,
            content: {
                subject: SUBJECTS[event],
                plainText: describe(event, item),
            },
            recipients: {
                to: [{ address: NOTIFY_TO }],
            },
        });

        await poller.pollUntilDone();
        console.log(`Sent ${event} notification to ${NOTIFY_TO}`);
    } catch (err) {
        console.error(`Failed to send ${event} notification`, err.message);
    }
}

module.exports = { notify };
