// ─── Application : navigation entre vues, recherche d'adresse, notifications ─

const App = (() => {
  // ── Navigation entre vues ───────────────────────────────────────────────────

  // Vue affichée : sert au rafraîchissement automatique (une seule vue est
  // rejouée à la fois, celle que l'utilisateur regarde).
  let activeView = 'map';

  function switchView(name) {
    activeView = name;
    document.querySelectorAll('.topnav-item').forEach((b) =>
      b.classList.toggle('active', b.dataset.view === name));
    document.querySelectorAll('.view').forEach((v) =>
      v.classList.toggle('active', v.id === 'view-' + name));

    if (name === 'map') MapView.invalidate();
    if (name === 'operators') Operators.show();
    if (name === 'compare') Compare.show();
    if (name === 'stats') Stats.show();
    if (name === 'history') History.show();
    if (name === 'ai') AIView.show();
  }

  // ── Recherche d'adresse (géocodage) ─────────────────────────────────────────

  function bindSearch() {
    const input = document.getElementById('search-input');
    const resultsBox = document.getElementById('search-results');
    let debounce = null;

    input.addEventListener('input', () => {
      clearTimeout(debounce);
      const q = input.value.trim();
      if (q.length < 3) { resultsBox.classList.remove('open'); return; }
      debounce = setTimeout(async () => {
        const results = await API.geocode(q);
        if (!results.length) {
          resultsBox.innerHTML = '<div class="search-result">Aucun résultat</div>';
        } else {
          resultsBox.innerHTML = results.map((r) => `
            <div class="search-result" data-lat="${escapeHtml(r.lat)}" data-lon="${escapeHtml(r.lon)}">
              ${escapeHtml(r.display_name.split(',')[0])}
              <small>${escapeHtml(r.display_name)}</small>
            </div>`).join('');
          resultsBox.querySelectorAll('.search-result[data-lat]').forEach((el) => {
            el.addEventListener('click', () => {
              switchView('map');
              MapView.flyTo(parseFloat(el.dataset.lat), parseFloat(el.dataset.lon), 13);
              resultsBox.classList.remove('open');
              input.value = el.textContent.trim().split('\n')[0];
            });
          });
        }
        resultsBox.classList.add('open');
      }, 400);
    });

    document.addEventListener('click', (e) => {
      if (!e.target.closest('.searchbox')) resultsBox.classList.remove('open');
    });
  }

  // ── Bannière "bientôt disponible" & toast ───────────────────────────────────

  let bannerTimer = null;
  function showSoonBanner(title, text) {
    const banner = document.getElementById('soon-banner');
    document.getElementById('soon-banner-title').textContent = title + ' — bientôt disponible';
    document.getElementById('soon-banner-text').textContent = text;
    banner.classList.add('show');
    clearTimeout(bannerTimer);
    bannerTimer = setTimeout(() => banner.classList.remove('show'), 6000);
  }

  let toastTimer = null;
  function toast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), 4000);
  }

  // ── Rafraîchissement automatique (ISS-09) ───────────────────────────────────
  //
  // Une mesure envoyée depuis le téléphone doit apparaître sans que
  // l'utilisateur recharge la page : la vue active est rejouée à intervalle
  // régulier. Trois garde-fous — rien pour un onglet caché (inutile de
  // solliciter l'API), rien pendant une saisie (le champ perdrait sa liste de
  // résultats), et rien quand une info-bulle est ouverte (le rendu la
  // refermerait sous les yeux de l'utilisateur).
  const REFRESH_INTERVAL_MS = 20000;
  let refreshing = false;

  function canRefresh() {
    if (document.hidden) return false;
    const el = document.activeElement;
    if (el && ['INPUT', 'SELECT', 'TEXTAREA'].includes(el.tagName)) return false;
    if (document.querySelector('.leaflet-popup')) return false;
    return true;
  }

  async function refreshActiveView() {
    if (refreshing || !canRefresh()) return;
    refreshing = true;
    try {
      switch (activeView) {
        case 'map': await MapView.refresh(); break;
        case 'stats': await Stats.show(); break;
        case 'operators': await Operators.show(); break;
        case 'history': await History.show(); break;
        case 'compare': await Compare.show(); break;
        case 'ai': await AIView.show(); break;
        default: break;
      }
    } catch (e) {
      // Un rafraîchissement qui échoue ne doit pas casser la vue affichée ni
      // empêcher le suivant : l'erreur est déjà signalée par le module concerné.
    } finally {
      refreshing = false;
    }
  }

  function startAutoRefresh() {
    setInterval(refreshActiveView, REFRESH_INTERVAL_MS);
    // Revenir sur l'onglet est le moment où l'on attend des données à jour :
    // on ne patiente pas le prochain intervalle.
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) refreshActiveView();
    });
  }

  // ── Initialisation ──────────────────────────────────────────────────────────

  function init() {
    document.querySelectorAll('.topnav-item').forEach((btn) =>
      btn.addEventListener('click', () => switchView(btn.dataset.view)));
    document.getElementById('soon-banner-close').addEventListener('click', () =>
      document.getElementById('soon-banner').classList.remove('show'));

    bindSearch();
    MapView.init();
    startAutoRefresh();

    // Liens profonds : ?view=stats ouvre une vue, ?usage=streaming sélectionne un usage
    const params = new URLSearchParams(location.search);
    const requested = params.get('view');
    if (requested && document.getElementById('view-' + requested)) switchView(requested);
    const usage = params.get('usage');
    if (usage) document.querySelector(`.usage-tab[data-usage="${usage}"]`)?.click();
  }

  document.addEventListener('DOMContentLoaded', init);

  return { toast, showSoonBanner, switchView };
})();
