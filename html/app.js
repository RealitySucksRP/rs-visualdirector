(function () {
    'use strict';

    var app = document.getElementById('app');
    var bootNotice = document.getElementById('bootNotice');
    var title = document.getElementById('title');
    var styleGrid = document.getElementById('styleGrid');
    var selectedLabel = document.getElementById('selectedLabel');
    var selectedDesc = document.getElementById('selectedDesc');
    var selectedCategory = document.getElementById('selectedCategory');
    var selectedRatings = document.getElementById('selectedRatings');
    var timecycleText = document.getElementById('timecycleText');
    var colorText = document.getElementById('colorText');
    var glowText = document.getElementById('glowText');
    var activeLabel = document.getElementById('activeLabel');
    var activeName = document.getElementById('activeName');
    var strengthRange = document.getElementById('strengthRange');
    var strengthReadout = document.getElementById('strengthReadout');
    var selectedStrengthValue = document.getElementById('selectedStrengthValue');
    var strengthMin = document.getElementById('strengthMin');
    var strengthMax = document.getElementById('strengthMax');
    var closeBtn = document.getElementById('closeBtn');
    var applyBtn = document.getElementById('applyBtn');
    var clearBtn = document.getElementById('clearBtn');
    var compareBtn = document.getElementById('compareBtn');
    var modeText = document.getElementById('modeText');
    var libraryCount = document.getElementById('libraryCount');
    var worldOverlay = document.getElementById('worldOverlay');

    var styles = [];
    var selected = null;
    var currentStyle = null;
    var currentStrength = 0;
    var closeAfterApply = false;
    var comparing = false;
    var resourceName = 'rs-visualdirector';
    var readySent = false;

    try {
        if (typeof GetParentResourceName === 'function') resourceName = GetParentResourceName();
    } catch (e) {}

    function safeText(el, value) {
        if (el) el.textContent = value == null ? '' : String(value);
    }

    function post(name, data) {
        data = data || {};
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://' + resourceName + '/' + name, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
            xhr.send(JSON.stringify(data));
        } catch (e) {}
    }

    function hexToRgb(hex, fallback) {
        var clean = String(hex || '').replace('#', '').trim();
        if (clean.length === 3) clean = clean.charAt(0) + clean.charAt(0) + clean.charAt(1) + clean.charAt(1) + clean.charAt(2) + clean.charAt(2);
        if (!/^[0-9a-fA-F]{6}$/.test(clean)) return fallback;
        return parseInt(clean.slice(0, 2), 16) + ', ' + parseInt(clean.slice(2, 4), 16) + ', ' + parseInt(clean.slice(4, 6), 16);
    }

    function setCssColor(style) {
        style = style || {};
        var color = style.color || '#43c6e8';
        var glow = style.glowColor || color;
        document.documentElement.style.setProperty('--accent', color);
        document.documentElement.style.setProperty('--glow', glow);
        document.documentElement.style.setProperty('--accent-rgb', hexToRgb(color, '67, 198, 232'));
        document.documentElement.style.setProperty('--glow-rgb', hexToRgb(glow, '128, 232, 255'));
    }

    function findStyle(name) {
        for (var i = 0; i < styles.length; i++) {
            if (styles[i].name === name) return styles[i];
        }
        return null;
    }

    function formatRatings(ratings) {
        ratings = ratings || {};
        var parts = [];
        if (typeof ratings.day === 'number') parts.push('DAY ' + ratings.day + '/10');
        if (typeof ratings.night === 'number') parts.push('NIGHT ' + ratings.night + '/10');
        if (typeof ratings.interior === 'number') parts.push('INDOOR ' + ratings.interior + '/10');
        return parts.join('  •  ');
    }

    function updateStrengthReadout() {
        var value = strengthRange ? Number(strengthRange.value || 0) : 0;
        safeText(selectedStrengthValue, value.toFixed(2));
    }

    function updateCardStates() {
        if (!styleGrid) return;
        var children = styleGrid.children;
        for (var i = 0; i < children.length; i++) {
            var card = children[i];
            var name = card.dataset ? card.dataset.style : '';
            card.classList.toggle('active', !!selected && name === selected.name);
            card.classList.toggle('live', currentStyle ? name === currentStyle : name === 'off');
        }
    }

    function setSelected(style) {
        if (!style) return;
        selected = style;
        setCssColor(style);
        safeText(selectedLabel, style.label || style.name);
        safeText(selectedDesc, style.description || 'No description set.');
        safeText(selectedCategory, (style.category || 'Other') + ' • ' + (style.intensity || 'Medium'));
        safeText(selectedRatings, formatRatings(style.ratings));
        safeText(timecycleText, style.timecycle || 'none');
        safeText(colorText, style.color || '#43c6e8');
        safeText(glowText, style.glowColor || style.color || '#80e8ff');

        if (strengthRange) {
            var minValue = typeof style.minStrength === 'number' ? style.minStrength : 0;
            var maxValue = typeof style.maxStrength === 'number' ? style.maxStrength : 1;
            var value = style.name === currentStyle ? currentStrength : Number(style.clear ? 0 : (style.strength || 0.35));
            strengthRange.min = String(minValue);
            strengthRange.max = String(maxValue);
            strengthRange.disabled = style.clear === true || style.name === 'off';
            strengthRange.value = Number(value).toFixed(2);
            safeText(strengthMin, Number(minValue).toFixed(2));
            safeText(strengthMax, Number(maxValue).toFixed(2));
        }

        updateStrengthReadout();
        updateCardStates();
    }

    function setState(styleName, strength, isComparing) {
        currentStyle = styleName || null;
        currentStrength = typeof strength === 'number' && !isNaN(strength) ? strength : 0;
        comparing = isComparing === true;

        var active = findStyle(currentStyle);
        safeText(activeLabel, active ? (active.label || active.name) : 'ORIGINAL GTA');
        safeText(activeName, comparing ? 'Comparing against Original GTA' : (active ? active.name : 'No global style'));
        safeText(strengthReadout, currentStrength.toFixed(2));
        if (compareBtn) compareBtn.classList.toggle('active', comparing);

        if (selected && selected.name === currentStyle && strengthRange) {
            strengthRange.value = currentStrength.toFixed(2);
            updateStrengthReadout();
        }
        updateCardStates();
    }

    function createTextNode(tagName, className, text) {
        var el = document.createElement(tagName);
        if (className) el.className = className;
        el.textContent = text == null ? '' : String(text);
        return el;
    }

    function renderStyles() {
        if (!styleGrid) return;
        styleGrid.innerHTML = '';

        for (var i = 0; i < styles.length; i++) {
            (function (style, index) {
                var card = document.createElement('button');
                card.type = 'button';
                card.className = 'style-btn';
                card.dataset.style = style.name;
                card.dataset.index = String(index + 1);
                card.style.setProperty('--btn-color', style.color || '#43c6e8');
                card.style.setProperty('--btn-rgb', hexToRgb(style.color || '#43c6e8', '67, 198, 232'));
                card.setAttribute('role', 'listitem');
                card.setAttribute('aria-label', 'Select ' + (style.label || style.name));

                card.appendChild(createTextNode('strong', '', style.label || style.name));
                card.appendChild(createTextNode('small', 'card-meta', (style.category || 'Other') + ' • ' + (style.intensity || 'Medium')));
                card.appendChild(createTextNode('em', 'card-id', style.name));
                card.appendChild(createTextNode('i', 'live-pin', ''));
                if (style.experimental) card.appendChild(createTextNode('span', 'experimental-tag', 'BETA'));

                card.addEventListener('click', function () { setSelected(style); });
                card.addEventListener('dblclick', function () { setSelected(style); applySelected(); });
                styleGrid.appendChild(card);
            })(styles[i], i);
        }

        safeText(libraryCount, styles.length + (styles.length === 1 ? ' MOOD' : ' MOODS'));
        updateCardStates();
    }

    function openMenu(data) {
        data = data || {};
        styles = Object.prototype.toString.call(data.styles) === '[object Array]' ? data.styles : [];
        closeAfterApply = data.closeAfterApply === true;
        document.body.classList.toggle('hide-window-labels', data.showWindowLabels === false);
        safeText(title, data.title || 'Visual Director');
        safeText(modeText, String(data.mode || 'sync').toUpperCase());

        renderStyles();
        currentStyle = data.currentStyle || null;
        currentStrength = Number(data.currentStrength || 0);
        setSelected(findStyle(currentStyle) || findStyle('off') || findStyle('gummy_air') || styles[0]);
        setState(currentStyle, currentStrength, false);

        if (bootNotice) bootNotice.style.display = 'none';
        if (app) {
            app.classList.remove('hidden');
            app.setAttribute('aria-hidden', 'false');
        }
    }

    function endCompare() {
        if (!comparing) return;
        comparing = false;
        if (compareBtn) compareBtn.classList.remove('active');
        post('compareEnd');
    }

    function closeMenu() {
        endCompare();
        if (app) {
            app.classList.add('hidden');
            app.setAttribute('aria-hidden', 'true');
        }
        if (bootNotice) bootNotice.style.display = 'none';
        post('close');
    }

    function applySelected() {
        if (!selected) return;
        endCompare();
        if (selected.clear === true || selected.name === 'off') {
            post('clearStyle');
        } else {
            post('applyStyle', {
                style: selected.name,
                strength: Number((strengthRange && strengthRange.value) || selected.strength || 0.35)
            });
        }
        if (closeAfterApply) closeMenu();
    }

    function clearStyle() {
        endCompare();
        post('clearStyle');
    }

    function beginCompare() {
        if (comparing || !currentStyle) return;
        comparing = true;
        if (compareBtn) compareBtn.classList.add('active');
        safeText(activeName, 'Comparing against Original GTA');
        post('compareStart');
    }

    function setWorldOverlay(data) {
        if (!worldOverlay) return;
        if (!data || data.enabled !== true) {
            worldOverlay.className = 'world-overlay hidden';
            worldOverlay.style.opacity = '0';
            return;
        }

        var type = String(data.overlayType || 'film').toLowerCase().replace(/[^a-z0-9_-]/g, '');
        var opacity = Number(data.opacity || 0.1);
        if (opacity < 0) opacity = 0;
        if (opacity > 0.45) opacity = 0.45;
        worldOverlay.className = 'world-overlay overlay-' + type;
        worldOverlay.style.opacity = String(opacity);
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'open') { openMenu(data); return; }
        if (data.action === 'close') {
            if (app) { app.classList.add('hidden'); app.setAttribute('aria-hidden', 'true'); }
            if (bootNotice) bootNotice.style.display = 'none';
            return;
        }
        if (data.action === 'state') {
            setState(data.currentStyle, Number(data.currentStrength || 0), data.comparing === true);
            return;
        }
        if (data.action === 'worldOverlay') { setWorldOverlay(data); return; }
        if (data.action === 'boot' && bootNotice) bootNotice.style.display = 'block';
    });

    window.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' || event.keyCode === 27) closeMenu();
        if (event.key === ' ' && compareBtn && document.activeElement === compareBtn) beginCompare();
    });
    window.addEventListener('keyup', function (event) {
        if (event.key === ' ' && comparing) endCompare();
    });
    window.addEventListener('blur', endCompare);

    if (strengthRange) strengthRange.addEventListener('input', updateStrengthReadout);
    if (closeBtn) closeBtn.addEventListener('click', closeMenu);
    if (applyBtn) applyBtn.addEventListener('click', applySelected);
    if (clearBtn) clearBtn.addEventListener('click', clearStyle);
    if (compareBtn) {
        compareBtn.addEventListener('mousedown', beginCompare);
        compareBtn.addEventListener('mouseup', endCompare);
        compareBtn.addEventListener('mouseleave', endCompare);
        compareBtn.addEventListener('touchstart', function (event) { event.preventDefault(); beginCompare(); }, { passive: false });
        compareBtn.addEventListener('touchend', function (event) { event.preventDefault(); endCompare(); }, { passive: false });
        compareBtn.addEventListener('touchcancel', endCompare);
    }

    function sendReadyOnce() {
        if (readySent) return;
        readySent = true;
        post('ready');
    }

    function boot() {
        if (app) { app.classList.add('hidden'); app.setAttribute('aria-hidden', 'true'); }
        if (bootNotice) bootNotice.style.display = 'none';
        setWorldOverlay({ enabled: false });
        sendReadyOnce();
    }

    if (document.readyState === 'complete' || document.readyState === 'interactive') {
        setTimeout(boot, 50);
    } else {
        window.addEventListener('load', function () { setTimeout(boot, 50); });
    }
})();
