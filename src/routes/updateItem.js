const db = require('../persistence');
const { notify } = require('../notifications');

module.exports = async (req, res) => {
    await db.updateItem(req.params.id, {
        name: req.body.name,
        completed: req.body.completed,
    });
    const item = await db.getItem(req.params.id);
    notify('updated', item);
    res.send(item);
};
