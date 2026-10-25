// Correction des requêtes Supabase pour le dashboard

// ❌ REQUÊTE INCORRECTE (cause erreur 400)
const incorrectQuery = `
planifications?select=agent_id,user_id,date,planned_start_time,planned_end_time,planned_hours,estimated_hours
&user_id=eq.88
&date=gte.2025-10-31
&date=lte.2025-11-29
`;

// ✅ REQUÊTE CORRECTE (utilise l'opérateur AND)
const correctQuery = `
planifications?select=agent_id,user_id,date,planned_start_time,planned_end_time,planned_hours,estimated_hours
&user_id=eq.88
&and=(date.gte.2025-10-31,date.lte.2025-11-29)
`;

// Alternative: utiliser les filtres séparés avec des parenthèses
const alternativeQuery = `
planifications?select=agent_id,user_id,date,planned_start_time,planned_end_time,planned_hours,estimated_hours
&user_id=eq.88
&date=gte.2025-10-31
&date=lte.2025-11-29
&order=date.desc
&limit=500
`;

// Fonction corrigée pour charger les données
async function loadPlanifications(userId, startDate, endDate) {
    try {
        const response = await fetch(
            `https://eoamsmtdspedumjmmeui.supabase.co/rest/v1/planifications?select=agent_id,user_id,date,planned_start_time,planned_end_time,planned_hours,estimated_hours&user_id=eq.${userId}&and=(date.gte.${startDate},date.lte.${endDate})&order=date.desc&limit=500`,
            {
                headers: {
                    'apikey': 'votre-api-key',
                    'Authorization': 'Bearer votre-token'
                }
            }
        );
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('Erreur lors du chargement des planifications:', error);
        throw error;
    }
}

// Fonction pour générer le rapport mensuel
async function generateMonthlyReport(agentId, month, year, projectName) {
    try {
        const response = await fetch(
            `/api/agents/monthly-report?agentId=${agentId}&month=${year}-${month}&ai=1&project_name=${encodeURIComponent(projectName)}`,
            {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            }
        );
        
        if (!response.ok) {
            if (response.status === 500) {
                // Essayer une version simplifiée si le serveur est surchargé
                console.log('Serveur surchargé, tentative avec version simplifiée...');
                return generateSimplifiedReport(agentId, month, year);
            }
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('Erreur lors de la génération du rapport:', error);
        
        // Afficher un message utilisateur friendly
        showUserMessage('Le serveur est temporairement indisponible. Veuillez réessayer dans quelques minutes.');
        
        // Retourner un rapport par défaut
        return {
            success: false,
            message: 'Rapport temporairement indisponible',
            data: getDefaultReportData(agentId, month, year)
        };
    }
}

// Rapport simplifié en cas d'erreur serveur
function generateSimplifiedReport(agentId, month, year) {
    return {
        success: true,
        message: 'Rapport simplifié (mode dégradé)',
        data: {
            agentId: agentId,
            month: month,
            year: year,
            totalHours: 0,
            plannedHours: 0,
            completedTasks: 0,
            status: 'Mode dégradé - Serveur indisponible'
        }
    };
}

// Données par défaut
function getDefaultReportData(agentId, month, year) {
    return {
        agentId: agentId,
        month: month,
        year: year,
        totalHours: 0,
        plannedHours: 0,
        completedTasks: 0,
        projects: [],
        status: 'Données non disponibles'
    };
}

// Message utilisateur
function showUserMessage(message) {
    const messageDiv = document.createElement('div');
    messageDiv.className = 'alert alert-warning';
    messageDiv.innerHTML = `
        <i class="fas fa-exclamation-triangle"></i>
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    
    // Insérer au début du dashboard
    const dashboard = document.querySelector('.dashboard-container');
    if (dashboard) {
        dashboard.insertBefore(messageDiv, dashboard.firstChild);
    }
}

// Export des fonctions
window.loadPlanifications = loadPlanifications;
window.generateMonthlyReport = generateMonthlyReport;
