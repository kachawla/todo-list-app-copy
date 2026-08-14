const db = require('../persistence');
const {v4 : uuid} = require('uuid');
const { notify } = require('../notifications');

module.exports = async (req, res) => {
    const item = {
        id: uuid(),
        name: req.body.name,
        completed: false,
    };

    await db.storeItem(item);
    notify('created', item);
    res.send(item);
};
