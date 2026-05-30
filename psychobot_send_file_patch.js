// ============================================================================
// PATCH PSYCHOBOT - ENDPOINT POUR ENVOYER DES FICHIERS VIA WHATSAPP
// ============================================================================
// À ajouter après l'endpoint /send-message dans index.js de PsychoBot

const fs = require('fs');
const path = require('path');

// Endpoint POST pour envoyer des fichiers WhatsApp
app.post('/send-file', async (req, res) => {
    try {
        const { phone, message, file_path, file_name } = req.body;

        // Validation
        if (!phone || !file_path) {
            return res.status(400).json({
                success: false,
                error: 'Missing phone or file_path in request body'
            });
        }

        // Vérifier que le fichier existe
        if (!fs.existsSync(file_path)) {
            return res.status(404).json({
                success: false,
                error: `File not found: ${file_path}`
            });
        }

        // Vérifier que le bot est connecté
        if (!sock || !sock.user) {
            return res.status(503).json({
                success: false,
                error: 'Bot not connected to WhatsApp'
            });
        }

        // Formater le numéro
        const cleanPhone = phone.replace(/[^0-9]/g, '');
        const jid = cleanPhone + '@s.whatsapp.net';

        // Lire le fichier
        const fileBuffer = fs.readFileSync(file_path);
        const fileName = file_name || path.basename(file_path);
        const mimeType = getMimeType(file_path);

        console.log(`[SEND-FILE] Sending ${fileName} (${fileBuffer.length} bytes) to ${phone}`);

        // Envoyer le fichier via WhatsApp
        await sock.sendMessage(jid, {
            document: fileBuffer,
            fileName: fileName,
            mimetype: mimeType,
            caption: message || `File: ${fileName}`
        });

        console.log(`[SEND-FILE] File sent to ${phone}: ${fileName}`);

        res.status(200).json({
            success: true,
            phone: phone,
            jid: jid,
            file_name: fileName,
            file_size: fileBuffer.length,
            message: 'File sent successfully',
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('[SEND-FILE ERROR]:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Helper function pour détecter le MIME type
function getMimeType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypes = {
        '.pdf': 'application/pdf',
        '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.doc': 'application/msword',
        '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        '.xls': 'application/vnd.ms-excel',
        '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        '.txt': 'text/plain',
        '.csv': 'text/csv',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.mp3': 'audio/mpeg',
        '.mp4': 'video/mp4',
        '.zip': 'application/zip'
    };
    return mimeTypes[ext] || 'application/octet-stream';
}

// Endpoint GET pour vérifier les fichiers disponibles
app.get('/send-file/list', async (req, res) => {
    try {
        const scanDir = './reports/morning_scan';

        if (!fs.existsSync(scanDir)) {
            return res.status(404).json({
                success: false,
                error: 'Scan directory not found'
            });
        }

        const files = fs.readdirSync(scanDir)
            .filter(f => f.endsWith('.docx') || f.endsWith('.pdf'))
            .map(f => ({
                name: f,
                path: path.join(scanDir, f),
                size: fs.statSync(path.join(scanDir, f)).size
            }))
            .sort((a, b) => b.size - a.size);

        res.status(200).json({
            success: true,
            directory: scanDir,
            files: files,
            count: files.length
        });

    } catch (error) {
        console.error('[SEND-FILE LIST ERROR]:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================================================
// USAGE:
//
// 1. Send file from local path:
//    curl -X POST "https://psychobot.../send-file" \
//      -H "Content-Type: application/json" \
//      -d '{
//        "phone": "+2290196911346",
//        "message": "Morning scan report",
//        "file_path": "D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx",
//        "file_name": "TradBOT_Morning_Scan_20260530_0657.docx"
//      }'
//
// 2. List available files:
//    curl "https://psychobot.../send-file/list"
//
// ============================================================================
