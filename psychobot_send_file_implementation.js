// ============================================================================
// PATCH PSYCHOBOT - ENDPOINT POUR ENVOYER DES FICHIERS VIA WHATSAPP
// ============================================================================
// À ajouter dans PsychoBot index.js après l'endpoint /send-message

const fs = require('fs');
const path = require('path');

// Endpoint POST pour envoyer des fichiers WhatsApp
app.post('/send-file', async (req, res) => {
    try {
        const { phone, message, file_path, file_name, file_url } = req.body;

        // Validation
        if (!phone || (!file_path && !file_url)) {
            return res.status(400).json({
                success: false,
                error: 'Missing phone and (file_path OR file_url)'
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

        let fileBuffer, fileName, mimeType;

        // Approche A: Fichier local
        if (file_path) {
            if (!fs.existsSync(file_path)) {
                return res.status(404).json({
                    success: false,
                    error: `File not found: ${file_path}`
                });
            }

            fileBuffer = fs.readFileSync(file_path);
            fileName = file_name || path.basename(file_path);
            mimeType = getMimeType(file_path);

            console.log(`[SEND-FILE] Local file: ${fileName} (${fileBuffer.length} bytes)`);
        }
        // Approche B: URL distante
        else if (file_url) {
            const axios = require('axios');

            try {
                const response = await axios.get(file_url, { responseType: 'arraybuffer' });
                fileBuffer = Buffer.from(response.data);
                fileName = file_name || path.basename(new URL(file_url).pathname);
                mimeType = response.headers['content-type'] || getMimeType(fileName);

                console.log(`[SEND-FILE] Remote file: ${fileName} (${fileBuffer.length} bytes)`);
            } catch (err) {
                return res.status(400).json({
                    success: false,
                    error: `Failed to fetch file from URL: ${err.message}`
                });
            }
        }

        // Envoyer le fichier via WhatsApp
        await sock.sendMessage(jid, {
            document: fileBuffer,
            fileName: fileName,
            mimetype: mimeType,
            caption: message || `Fichier: ${fileName}`
        });

        console.log(`[SEND-FILE] ✅ File sent to ${phone}: ${fileName}`);

        res.status(200).json({
            success: true,
            phone: phone,
            jid: jid,
            file_name: fileName,
            file_size: fileBuffer.length,
            message: 'File sent successfully via WhatsApp',
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

// Helper: Détecter MIME type
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

// ============================================================================
// USAGE EXEMPLES
// ============================================================================

/*

1. Envoyer un fichier local:
   curl -X POST "https://psychobot.../send-file" \
     -H "Content-Type: application/json" \
     -d '{
       "phone": "+2290196911346",
       "message": "Voici votre rapport",
       "file_path": "D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx",
       "file_name": "Morning_Scan.docx"
     }'

2. Envoyer un fichier depuis une URL distante:
   curl -X POST "https://psychobot.../send-file" \
     -H "Content-Type: application/json" \
     -d '{
       "phone": "+2290196911346",
       "message": "Rapport automatisé",
       "file_url": "https://example.com/reports/report.pdf",
       "file_name": "Report_2026.pdf"
     }'

3. Via Python:
   import requests

   resp = requests.post(
       "https://psychobot.../send-file",
       json={
           "phone": "+2290196911346",
           "message": "Scan matinal",
           "file_path": "D:/Dev/TradBOT/reports/morning_scan/TradBOT_Morning_Scan_20260530_0657.docx"
       }
   )
   print(resp.json())

*/

// ============================================================================
// INSTALLATION
// ============================================================================

// 1. Ajouter ce code à PsychoBot index.js (après /send-message endpoint)
// 2. Redémarrer PsychoBot
// 3. Utiliser /send-file endpoint comme montré ci-dessus
