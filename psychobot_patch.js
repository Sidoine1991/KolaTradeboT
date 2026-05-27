// ============================================================================
// PATCH PSYCHOBOT - ENDPOINT POUR ENVOYER DES MESSAGES WHATSAPP
// ============================================================================
// À ajouter après la ligne 204 (après app.get('/ping', ...))
// dans le fichier index.js de PsychoBot

// Endpoint POST pour envoyer des messages WhatsApp
app.post('/send-message', async (req, res) => {
    try {
        const { phone, message } = req.body;

        // Validation
        if (!phone || !message) {
            return res.status(400).json({
                success: false,
                error: 'Missing phone or message in request body'
            });
        }

        // Vérifier que le bot est connecté
        if (!sock || !sock.user) {
            return res.status(503).json({
                success: false,
                error: 'Bot not connected to WhatsApp'
            });
        }

        // Formater le numéro (enlever le + et ajouter @s.whatsapp.net)
        const cleanPhone = phone.replace(/[^0-9]/g, '');
        const jid = cleanPhone + '@s.whatsapp.net';

        // Envoyer le message
        await sock.sendMessage(jid, { text: message });

        console.log(`[SEND-MESSAGE] Message sent to ${phone}: ${message.substring(0, 50)}...`);

        res.status(200).json({
            success: true,
            phone: phone,
            jid: jid,
            message: 'Message sent successfully',
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('[SEND-MESSAGE ERROR]:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// CORS pour permettre les requêtes depuis votre script Python
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(200);
    }
    next();
});
