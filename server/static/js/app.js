let state = {
    currentStep: 1,
    selectedLob: null,
    models: [],
    results: {},
    currentModel: null
};

// --- On page load: always start fresh at Step 1 ---
document.addEventListener('DOMContentLoaded', async () => {
    localStorage.removeItem('stm_dbt_last_session');
    loadLobInfo();
});

async function loadLobInfo() {
    try {
        const resp = await fetch('/api/lobs');
        const data = await resp.json();
        for (const lob of data.lobs) {
            const el = document.getElementById(`${lob.id}-info`);
            if (el) {
                el.textContent = `STM: ${lob.stm_file} | SQL: ${lob.sql_count} models`;
                el.className = 'text-xs text-green-400';
            }
        }
    } catch (e) {
        console.error('Failed to load LOB info', e);
    }
}

// --- Step 1: Select LOB ---
async function selectLob(lob) {
    state.selectedLob = lob;

    // Highlight selected card
    document.querySelectorAll('.lob-card').forEach(card => {
        card.classList.remove('border-cyan-500', 'bg-slate-900/50');
        card.classList.add('border-slate-600');
    });
    event.currentTarget.classList.remove('border-slate-600');
    event.currentTarget.classList.add('border-cyan-500', 'bg-slate-900/50');

    await loadModelsForLob(lob);
}

async function loadModelsForLob(lob) {
    showLoading('Loading models...');
    try {
        const resp = await fetch(`/api/lobs/${lob}/models`);
        const data = await resp.json();
        state.models = data.models || [];
        hideLoading();
        goToStep(2);
        renderModelList();
    } catch (e) {
        hideLoading();
        alert('Error loading models: ' + e.message);
    }
}

// --- Step Navigation ---
function goToStep(step) {
    document.getElementById(`step-${state.currentStep}`).classList.add('hidden');
    document.getElementById(`step-${step}`).classList.remove('hidden');
    state.currentStep = step;
    updateProgressBar();
}

function updateProgressBar() {
    for (let i = 1; i <= 3; i++) {
        const indicator = document.getElementById(`step${i}-indicator`);
        if (i < state.currentStep) {
            indicator.className = 'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold bg-green-600 text-white';
            indicator.innerHTML = '&#10003;';
        } else if (i === state.currentStep) {
            indicator.className = 'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold bg-cyan-600 text-white';
            indicator.textContent = i;
        } else {
            indicator.className = 'w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold bg-slate-600 text-slate-300';
            indicator.textContent = i;
        }
    }
}

// --- Back to Models (uses cached state, no re-fetch) ---
function backToModels() {
    if (state.models.length > 0) {
        goToStep(2);
        renderModelList();
    } else if (state.selectedLob) {
        loadModelsForLob(state.selectedLob);
    } else {
        goToStep(1);
    }
}

// --- Step 2: Model List ---
function renderModelList() {
    const container = document.getElementById('model-list');
    const lobLabel = state.selectedLob === 'bop' ? 'Business Owners Policy' : 'Commercial Auto';
    document.getElementById('selected-lob-label').textContent = lobLabel;
    document.getElementById('model-count').textContent = `${state.models.length} models available`;

    if (state.models.length === 0) {
        container.innerHTML = '<p class="text-slate-400 p-4">No models found for this LOB.</p>';
        return;
    }

    container.innerHTML = state.models.map(m => `
        <div class="model-item flex items-center gap-4 p-4 bg-slate-900 rounded-lg border border-slate-700 hover:border-cyan-500 cursor-pointer transition"
             onclick="selectAndCompare('${m.model_name}')">
            <div class="w-10 h-10 bg-slate-800 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-cyan-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
            </div>
            <div class="flex-1">
                <p class="font-medium text-white">${m.model_name}</p>
                <p class="text-xs text-slate-400">STM tab: ${m.stm_tab || 'Not matched'} | ${m.column_count || '?'} columns</p>
            </div>
            <div class="flex items-center gap-2">
                <span class="text-xs px-2 py-1 rounded ${m.has_sql ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'}">
                    SQL ${m.has_sql ? '&#10003;' : '&#10007;'}
                </span>
                <svg class="w-5 h-5 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
            </div>
        </div>
    `).join('');
}

// --- Select model and auto-compare ---
async function selectAndCompare(modelName) {
    const model = state.models.find(m => m.model_name === modelName);
    if (!model || !model.has_sql) {
        alert('This model has no SQL file available.');
        return;
    }

    showLoading('Running comparison...', `Model: ${modelName}`);
    try {
        const resp = await fetch('/api/compare', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ models: [modelName], lob: state.selectedLob })
        });
        const data = await resp.json();

        if (!resp.ok) {
            hideLoading();
            alert(`Comparison error: ${data.error || 'Unknown error'}`);
            return;
        }

        state.results = data.results;
        state.currentModel = modelName;
        hideLoading();
        goToStep(3);
        renderResults();
    } catch (e) {
        hideLoading();
        alert('Error: ' + e.message);
    }
}

// --- Compare All ---
async function runComparison(mode) {
    const models = state.models.filter(m => m.has_sql).map(m => m.model_name);
    if (models.length === 0) {
        alert('No models with SQL available');
        return;
    }

    showLoading('Running comparison...', `Processing ${models.length} model(s)`);
    try {
        const resp = await fetch('/api/compare', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ models, lob: state.selectedLob })
        });
        const data = await resp.json();

        if (!resp.ok) {
            hideLoading();
            alert(`Comparison error: ${data.error || 'Unknown error'}`);
            return;
        }

        state.results = data.results;
        state.currentModel = Object.keys(data.results)[0];
        hideLoading();
        goToStep(3);
        renderResults();
    } catch (e) {
        hideLoading();
        alert('Error: ' + e.message);
    }
}

// --- Step 3: Results ---
function renderResults() {
    const modelNames = Object.keys(state.results);

    const tabsContainer = document.getElementById('model-tabs');
    if (modelNames.length > 1) {
        tabsContainer.classList.remove('hidden');
        tabsContainer.innerHTML = modelNames.map(name =>
            `<button onclick="switchModel('${name}')" class="model-tab px-3 py-1 text-sm rounded-lg ${name === state.currentModel ? 'bg-cyan-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600'}">${name}</button>`
        ).join('');
    } else {
        tabsContainer.classList.add('hidden');
    }

    renderModelResults(state.currentModel);
}

function switchModel(name) {
    state.currentModel = name;
    document.querySelectorAll('.model-tab').forEach(btn => {
        btn.className = btn.textContent === name
            ? 'model-tab px-3 py-1 text-sm rounded-lg bg-cyan-600 text-white'
            : 'model-tab px-3 py-1 text-sm rounded-lg bg-slate-700 text-slate-300 hover:bg-slate-600';
    });
    renderModelResults(name);
}

function renderModelResults(modelName) {
    const result = state.results[modelName];
    if (!result || result.error) {
        document.getElementById('results-subtitle').textContent = `Model: ${modelName} — Error: ${result?.error || 'Unknown'}`;
        return;
    }

    const summary = result.summary;
    document.getElementById('results-subtitle').textContent = `Model: ${modelName} | STM Tab: ${result.stm_tab}`;
    document.getElementById('summary-stm-total').textContent = summary.total_stm_columns;
    document.getElementById('summary-dbt-total').textContent = summary.total_dbt_columns;
    document.getElementById('summary-match').textContent = summary.matched_columns;
    document.getElementById('summary-mismatch').textContent = summary.datatype_mismatches;
    document.getElementById('summary-extra').textContent = summary.extra_in_dbt;
    document.getElementById('summary-rate').textContent = summary.match_rate;

    renderTable(result.detailed);
}

function renderTable(rows, filter = 'all') {
    const tbody = document.getElementById('results-tbody');
    const filtered = filter === 'all' ? rows : rows.filter(r => (r.status || r.datatype_comparison) === filter);

    tbody.innerHTML = filtered.map(row => {
        const colCompare = row.column_name_compare || '-';
        const colCompareClass = colCompare.startsWith('MATCH') ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300';
        const scdCompare = row.scd_comparison || '-';
        const scdClass = scdCompare === 'MATCH' ? 'bg-green-900 text-green-300' : (scdCompare === 'MISMATCH' ? 'bg-red-900 text-red-300' : 'text-slate-400');
        return `
        <tr class="border-b border-slate-800 hover:bg-slate-900/50">
            <td class="px-4 py-3 font-medium text-white">${row.stm_column || '-'}</td>
            <td class="px-4 py-3 text-slate-300">${row.dbt_column || '-'}</td>
            <td class="px-4 py-3">
                <span class="px-2 py-0.5 text-xs font-medium rounded ${colCompareClass}">
                    ${colCompare}
                </span>
            </td>
            <td class="px-4 py-3 text-slate-300">${row.stm_datatype || '-'}</td>
            <td class="px-4 py-3 text-slate-300">${row.dbt_datatype || '-'}</td>
            <td class="px-4 py-3">
                <span class="px-2 py-0.5 text-xs font-medium rounded ${row.datatype_comparison === 'MATCH' ? 'bg-green-900 text-green-300' : 'bg-red-900 text-red-300'}">
                    ${row.datatype_comparison}
                </span>
            </td>
            <td class="px-4 py-3 text-slate-300 text-xs">${row.stm_scd_type || '-'}</td>
            <td class="px-4 py-3 text-slate-300 text-xs">${row.dbt_scd_type || '-'}</td>
            <td class="px-4 py-3">
                <span class="px-2 py-0.5 text-xs font-medium rounded ${scdClass}">
                    ${scdCompare}
                </span>
            </td>
            <td class="px-4 py-3 text-slate-300 text-xs">${row.column_logic || '-'}</td>
            <td class="px-4 py-3 text-slate-300 text-xs">${row.transformation_logic || '-'}</td>
            <td class="px-4 py-3 text-slate-300 text-xs font-mono">${row.source_expression || '-'}</td>
            <td class="px-4 py-3 text-xs ${row.suggestion === 'No action required' ? 'text-green-400' : 'text-amber-400'}">${row.suggestion || '-'}</td>
        </tr>`;
    }).join('');
}

function filterResults(filter) {
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.className = 'filter-btn px-3 py-1 text-sm rounded-lg ' +
            (btn.textContent.toLowerCase().includes(filter.toLowerCase()) || (filter === 'all' && btn.textContent === 'All')
                ? 'bg-cyan-600 text-white' : 'bg-slate-700 text-slate-300 hover:bg-slate-600');
    });
    const result = state.results[state.currentModel];
    if (result && result.detailed) renderTable(result.detailed, filter);
}

// --- View Tabs (Comparison / STM / SQL / Compiled) ---
function switchView(view) {
    document.querySelectorAll('.view-tab').forEach(tab => {
        tab.className = 'view-tab px-4 py-2 text-sm font-medium border-b-2 border-transparent text-slate-400 hover:text-slate-200';
    });
    document.getElementById(`view-tab-${view}`).className = 'view-tab px-4 py-2 text-sm font-medium border-b-2 border-cyan-500 text-cyan-400';

    document.getElementById('view-comparison').classList.add('hidden');
    document.getElementById('view-stm').classList.add('hidden');
    document.getElementById('view-sql').classList.add('hidden');
    document.getElementById('view-compiled').classList.add('hidden');
    document.getElementById(`view-${view}`).classList.remove('hidden');

    if (view === 'stm') loadStmView();
    if (view === 'sql') loadSqlView();
    if (view === 'compiled') loadCompiledView();
}

async function loadStmView() {
    if (!state.currentModel) return;
    const tbody = document.getElementById('stm-tbody');
    const info = document.getElementById('stm-view-info');

    try {
        const resp = await fetch(`/api/models/${state.currentModel}/details?lob=${state.selectedLob}`);
        const data = await resp.json();

        info.textContent = `Tab: ${data.stm_tab || '?'} | ${data.columns.length} columns`;
        tbody.innerHTML = data.columns.map((col, i) => `
            <tr class="border-b border-slate-800 hover:bg-slate-900/50">
                <td class="px-4 py-2 text-slate-500 text-xs">${i + 1}</td>
                <td class="px-4 py-2 font-medium text-white">${col.target_column}</td>
                <td class="px-4 py-2 text-slate-300">${col.source_table || '-'}</td>
                <td class="px-4 py-2 text-slate-300 text-xs font-mono">${col.source_column || '-'}</td>
                <td class="px-4 py-2 text-slate-300">${col.data_type || '-'}</td>
                <td class="px-4 py-2 text-slate-300 text-xs">${col.business_rule || '-'}</td>
            </tr>
        `).join('');
    } catch (e) {
        info.textContent = 'Error loading STM data';
        tbody.innerHTML = '';
    }
}

async function loadSqlView() {
    if (!state.currentModel) return;
    const content = document.getElementById('sql-code-content');
    const info = document.getElementById('sql-view-info');

    try {
        const resp = await fetch(`/api/models/${state.currentModel}/sql?lob=${state.selectedLob}`);
        const data = await resp.json();

        info.textContent = `File: ${state.currentModel}.sql | ${data.line_count} lines`;
        content.textContent = data.content;
    } catch (e) {
        info.textContent = 'Error loading SQL file';
        content.textContent = 'Could not load SQL content.';
    }
}

async function loadCompiledView() {
    if (!state.currentModel) return;
    const content = document.getElementById('compiled-code-content');
    const info = document.getElementById('compiled-view-info');

    try {
        const resp = await fetch(`/api/models/${state.currentModel}/compiled?lob=${state.selectedLob}`);
        const data = await resp.json();

        info.textContent = `File: ${state.currentModel}.sql (Jinja resolved) | ${data.line_count} lines`;
        content.textContent = data.content;
    } catch (e) {
        info.textContent = 'Error loading compiled SQL';
        content.textContent = 'Could not load compiled content.';
    }
}

// --- Downloads ---
function downloadResults() {
    if (!state.currentModel) return;
    window.location.href = `/api/results/download/${state.currentModel}`;
}

function downloadAll() {
    window.location.href = '/api/results/download-all';
}


// --- Utilities ---
function showLoading(text, detail) {
    document.getElementById('loading-text').textContent = text || 'Processing...';
    document.getElementById('loading-detail').textContent = detail || '';
    document.getElementById('loading-overlay').classList.remove('hidden');
}

function hideLoading() {
    document.getElementById('loading-overlay').classList.add('hidden');
}

function startOver() {
    localStorage.removeItem('stm_dbt_last_session');
    state = { currentStep: 1, selectedLob: null, models: [], results: {}, currentModel: null };
    document.getElementById('step-3').classList.add('hidden');
    document.getElementById('step-2').classList.add('hidden');
    document.getElementById('step-1').classList.remove('hidden');
    state.currentStep = 1;
    updateProgressBar();
    document.querySelectorAll('.lob-card').forEach(card => {
        card.classList.remove('border-cyan-500', 'bg-slate-900/50');
        card.classList.add('border-slate-600');
    });
    loadLobInfo();
}
