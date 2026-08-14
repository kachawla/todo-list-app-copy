const db = require('../persistence');
const { notify } = require('../notifications');

module.exports = async (req, res) => {
    await db.removeItem(req.params.id);
    notify('deleted', { id: req.params.id });
    res.sendStatus(200);
};
