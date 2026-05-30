# PsychoBot File Attachment Support

## Status Actuel
- ✅ Envoi de messages texte: Fonctionne
- ❌ Envoi de fichiers: Nécessite implémentation

## Pour Envoyer des Fichiers (Word, PDF, etc.)

### Option 1: Héberger le fichier sur un serveur
```bash
# Uploader le fichier sur Render ou AWS S3
# Puis envoyer le lien via WhatsApp
```

### Option 2: Implémenter /send-file dans PsychoBot (index.js)
```javascript
const fs = require('fs');
const path = require('path');

app.post('/send-file', async (req, res) => {
    try {
        const { phone, message, file_path, file_name } = req.body;

        // Validation
        if (!phone || !file_path) {
            return res.status(400).json({
                success: false,
                error: 'Missing phone or file_path'
            });
        }

        // Vérifier bot connecté
        if (!sock || !sock.user) {
            return res.status(503).json({
                success: false,
                error: 'Bot not connected to WhatsApp'
            });
        }

        // Lire le fichier
        const fileBuffer = fs.readFileSync(file_path);
        const fileName = file_name || path.basename(file_path);
        
        const jid = phone.replace(/[^0-9]/g, '') + '@s.whatsapp.net';

        // Envoyer via WhatsApp
        await sock.sendMessage(jid, {
            document: fileBuffer,
            fileName: fileName,
            caption: message || `File: ${fileName}`
        });

        res.json({ success: true, fileName });

    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
```

### Option 3: Utiliser WhatsApp Cloud API
```bash
# Envoyer un fichier via l'API officielle Meta/WhatsApp
curl -X POST "https://graph.instagram.com/v18.0/PHONE_ID/media" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@rapport.docx" \
  -F "type=document"
```

## Fichier Actuel
- **Nom**: TradBOT_Morning_Scan_20260530_0657.docx
- **Taille**: 35.0 KB
- **Chemin**: D:\Dev\TradBOT\reports\morning_scan\
- **Contenu**: Scan matinal avec symboles du jour

## Prochaines Étapes
1. Implémenter /send-file endpoint dans PsychoBot
2. OU héberger le fichier et envoyer le lien
3. OU intégrer WhatsApp Cloud API
