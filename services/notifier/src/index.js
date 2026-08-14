const express = require('express');
const nodemailer = require('nodemailer');

const {
    SMTP_HOST,
    SMTP_PORT = '587',
    SMTP_USER,
    SMTP_PASSWORD,
    SMTP_SECURE = 'false',
    NOTIFY_FROM,
    NOTIFY_TO,
    PORT = '3001',
} = process.env;

const app = express();
app.use(express.json());

const transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: SMTP_SECURE === 'true',
    auth: SMTP_USER ? { user: SMTP_USER, pass: SMTP_PASSWORD } : undefined,
});

const SUBJECTS = {
    created: 'Todo item created',
    updated: 'Todo item updated',
    deleted: 'Todo item deleted',
};

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

app.get('/health', (req, res) => res.sendStatus(200));

app.post('/notify', async (req, res) => {
    const { event, item } = req.body || {};

    if (!SUBJECTS[event]) {
        return res.status(400).send({ error: `Unknown event: ${event}` });
    }

    try {
        await transporter.sendMail({
            from: NOTIFY_FROM,
            to: NOTIFY_TO,
            subject: SUBJECTS[event],
            text: describe(event, item),
        });
        console.log(`Sent ${event} notification to ${NOTIFY_TO}`);
        res.sendStatus(202);
    } catch (err) {
        console.error(`Failed to send ${event} notification`, err.message);
        res.status(502).send({ error: 'Failed to send notification' });
    }
});

app.listen(Number(PORT), () =>
    console.log(`Notifier listening on port ${PORT}`),
);

const gracefulShutdown = () => {
    transporter.close();
    process.exit();
};

process.on('SIGINT', gracefulShutdown);
process.on('SIGTERM', gracefulShutdown);
