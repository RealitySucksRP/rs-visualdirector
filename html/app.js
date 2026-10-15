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
    var phoneShell = document.querySelector('.phone-shell');
    var moveHandle = document.getElementById('moveHandle');
    var sizeDownBtn = document.getElementById('sizeDownBtn');
    var sizeUpBtn = document.getElementById('sizeUpBtn');
    var resetLayoutBtn = document.getElementById('resetLayoutBtn');
    var categoryFilters = document.getElementById('categoryFilters');
    var noResults = document.getElementById('noResults');
    var viewModeBtn = document.getElementById('viewModeBtn');
    var previewBtn = document.getElementById('previewBtn');
    var previewBanner = document.getElementById('previewBanner');
    var captureGalleryBtn = document.getElementById('captureGalleryBtn');
    var galleryCount = document.getElementById('galleryCount');
    var galleryStatus = document.getElementById('galleryStatus');
    var categoryPrevBtn = document.getElementById('categoryPrevBtn');
    var categoryNextBtn = document.getElementById('categoryNextBtn');
    var saveMomentBtn = document.getElementById('saveMomentBtn');
    var saveMomentPanelBtn = document.getElementById('saveMomentPanelBtn');
    var openMomentsBtn = document.getElementById('openMomentsBtn');
    var closeMomentsBtn = document.getElementById('closeMomentsBtn');
    var momentsPanel = document.getElementById('momentsPanel');
    var momentsCount = document.getElementById('momentsCount');
    var momentNameInput = document.getElementById('momentNameInput');
    var momentStatus = document.getElementById('momentStatus');
    var momentsList = document.getElementById('momentsList');
    var momentLightbox = document.getElementById('momentLightbox');
    var momentLightboxImage = document.getElementById('momentLightboxImage');
    var momentLightboxTitle = document.getElementById('momentLightboxTitle');
    var closeMomentLightboxBtn = document.getElementById('closeMomentLightboxBtn');

    var styles = [];
    var selected = null;
    var currentStyle = null;
    var currentStrength = 0;
    var closeAfterApply = false;
    var comparing = false;
    var resourceName = 'rs-visualdirector';
    var readySent = false;
    var activeFilter = 'All';
    var layoutKey = 'rs_visualdirector_layout_v2';
    var viewMode = 'studio';
    var layouts = { phone: { x: 0.5, y: 0.5, scale: 1 }, studio: { x: 0.5, y: 0.5, scale: 1 } };
    var layout = layouts.studio;
    var layoutInitialized = false;
    var drag = null;
    var previewActive = false;
    var previewStyle = null;
    var allowGameplayCaptures = true;
    var galleryKey = 'rs_vd_genuine_captures_v1_';
    var capturedThumbnails = {};
    var galleryPersistent = true;
    var galleryQueue = [];
    var galleryRunning = false;
    var galleryWaiting = null;
    var galleryTimeout = null;
    var galleryTotal = 0;
    var momentsStorageKey = 'rs_vd_live_moments_v1';
    var savedMoments = [];
    var momentsPersistent = true;
    var momentCapturePending = false;
    var momentCaptureTimeout = null;
    var momentCaptureContext = null;
    var momentCaptureTicket = 0;
    var momentPanelOpen = false;

    try {
        if (typeof GetParentResourceName === 'function') resourceName = GetParentResourceName();
    } catch (e) {}


    // Layout is local to the player. Cfx KVP persists even if NUI cache is reset.
    // NUI localStorage is a fallback for standalone HTML previews.
    function finiteNumber(value, fallback) {
        var number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    function between(value, min, max) {
        return Math.min(max, Math.max(min, value));
    }

    function normalizeLayout(input) {
        input = input && typeof input === 'object' ? input : {};
        return {
            x: between(finiteNumber(input.x, 0.5), 0, 1),
            y: between(finiteNumber(input.y, 0.5), 0, 1),
            scale: between(finiteNumber(input.scale, 1), 0.72, 1.15)
        };
    }

    function normalizeLayouts(input) {
        input = input && typeof input === 'object' ? input : {};
        return {
            view: input.view === 'phone' ? 'phone' : 'studio',
            phone: normalizeLayout(input.phone || (input.x !== undefined ? input : null)),
            studio: normalizeLayout(input.studio)
        };
    }

    function localLayout() {
        try {
            var data = window.localStorage.getItem(layoutKey);
            if (data) return normalizeLayouts(JSON.parse(data));
        } catch (e) {}
        return null;
    }

    function saveLayout() {
        layouts[viewMode] = normalizeLayout(layout);
        layout = layouts[viewMode];
        var data = { view: viewMode, phone: layouts.phone, studio: layouts.studio };
        try { window.localStorage.setItem(layoutKey, JSON.stringify(data)); } catch (e) {}
        post('saveLayout', data);
    }

    function setViewMode(next) {
        viewMode = next === 'phone' ? 'phone' : 'studio';
        layout = layouts[viewMode];
        if (app) app.classList.toggle('studio-mode', viewMode === 'studio');
        if (viewModeBtn) {
            viewModeBtn.textContent = viewMode === 'studio' ? 'PHONE VIEW' : 'STUDIO VIEW';
            viewModeBtn.title = viewMode === 'studio' ? 'Switch to original phone' : 'Switch to widescreen Director Studio';
        }
        positionPhone();
        saveLayout();
    }

    function positionPhone() {
        if (!phoneShell || !app || app.classList.contains('hidden')) return;
        var w = Math.max(1, window.innerWidth);
        var h = Math.max(1, window.innerHeight);
        var margin = 12;
        var baseW = phoneShell.offsetWidth || (viewMode === 'studio' ? 1080 : 460);
        var baseH = phoneShell.offsetHeight || 880;
        var effectiveScale = Math.min(layout.scale,
            (w - margin * 2) / baseW,
            (h - margin * 2) / baseH);
        effectiveScale = Math.max(0.1, effectiveScale);
        var halfW = baseW * effectiveScale / 2;
        var halfH = baseH * effectiveScale / 2;
        var cx = between(layout.x * w, halfW + margin, w - halfW - margin);
        var cy = between(layout.y * h, halfH + margin, h - halfH - margin);
        phoneShell.style.left = cx + 'px';
        phoneShell.style.top = cy + 'px';
        phoneShell.style.transform = 'translate(-50%, -50%) scale(' + effectiveScale + ')';
        layout.x = cx / w;
        layout.y = cy / h;
        if (sizeDownBtn) sizeDownBtn.disabled = layout.scale <= 0.721;
        if (sizeUpBtn) sizeUpBtn.disabled = layout.scale >= 1.149;
    }

    function adjustPhoneSize(delta) {
        layout.scale = between(Math.round((layout.scale + delta) * 100) / 100, 0.72, 1.15);
        positionPhone();
        saveLayout();
    }

    function beginMove(event) {
        if (!phoneShell || !app || app.classList.contains('hidden')) return;
        if (event.button !== undefined && event.button !== 0) return;
        var bounds = phoneShell.getBoundingClientRect();
        drag = {
            id: event.pointerId,
            startX: event.clientX,
            startY: event.clientY,
            centerX: (bounds.left + bounds.right) / 2,
            centerY: (bounds.top + bounds.bottom) / 2
        };
        document.body.classList.add('moving-phone');
        event.preventDefault();
    }

    function updateMove(event) {
        if (!drag || (event.pointerId !== undefined && event.pointerId !== drag.id)) return;
        layout.x = (drag.centerX + event.clientX - drag.startX) / Math.max(1, window.innerWidth);
        layout.y = (drag.centerY + event.clientY - drag.startY) / Math.max(1, window.innerHeight);
        positionPhone();
        event.preventDefault();
    }

    function stopMove(event) {
        if (!drag || (event && event.pointerId !== undefined && event.pointerId !== drag.id)) return;
        drag = null;
        document.body.classList.remove('moving-phone');
        saveLayout();
    }

    function updateCategoryArrows() {
        if (!categoryFilters) return;
        var maxScroll = Math.max(0, categoryFilters.scrollWidth - categoryFilters.clientWidth);
        if (categoryPrevBtn) categoryPrevBtn.disabled = categoryFilters.scrollLeft < 2;
        if (categoryNextBtn) categoryNextBtn.disabled = categoryFilters.scrollLeft >= maxScroll - 2;
    }

    function scrollCategoryStrip(direction) {
        if (!categoryFilters) return;
        categoryFilters.scrollBy({ left: direction * Math.max(140, categoryFilters.clientWidth * 0.65), behavior: 'smooth' });
        window.setTimeout(updateCategoryArrows, 280);
    }

    function changeFilter(category) {
        activeFilter = category;
        if (categoryFilters) {
            var buttons = categoryFilters.querySelectorAll('button');
            for (var i = 0; i < buttons.length; i++) {
                var active = buttons[i].dataset.category === category;
                buttons[i].classList.toggle('active', active);
                buttons[i].setAttribute('aria-pressed', active ? 'true' : 'false');
            }
        }
        var visible = 0;
        if (styleGrid) {
            for (var j = 0; j < styleGrid.children.length; j++) {
                var card = styleGrid.children[j];
                var match = category === 'All' || card.dataset.category === category;
                card.classList.toggle('filtered-out', !match);
                if (match) visible++;
            }
        }
        safeText(libraryCount, visible + ' / ' + styles.length + ' LOOKS');
        if (noResults) noResults.classList.toggle('hidden', visible !== 0);
        // Every filter change begins with the first result rather than leaving
        // the player at the bottom of a previously longer category.
        if (styleGrid) styleGrid.scrollTop = 0;
        if (categoryFilters) {
            var activeChip = categoryFilters.querySelector('.filter-chip.active');
            if (activeChip) {
                var left = activeChip.offsetLeft - categoryFilters.offsetLeft;
                if (left < categoryFilters.scrollLeft) categoryFilters.scrollLeft = left;
                else if (left + activeChip.offsetWidth > categoryFilters.scrollLeft + categoryFilters.clientWidth)
                    categoryFilters.scrollLeft = left + activeChip.offsetWidth - categoryFilters.clientWidth;
            }
        }
        updateCategoryArrows();
    }

    function renderFilters() {
        if (!categoryFilters) return;
        categoryFilters.innerHTML = '';
        var categories = ['All'];
        for (var i = 0; i < styles.length; i++) {
            var category = String(styles[i].category || 'Other');
            if (categories.indexOf(category) === -1) categories.push(category);
        }
        for (var j = 0; j < categories.length; j++) {
            (function (category) {
                var button = createTextNode('button', 'filter-chip', category === 'All' ? 'ALL LOOKS' : category.toUpperCase());
                button.type = 'button';
                button.dataset.category = category;
                button.addEventListener('click', function () { changeFilter(category); });
                categoryFilters.appendChild(button);
            })(categories[j]);
        }
        changeFilter('All');
        window.requestAnimationFrame(updateCategoryArrows);
    }

    function safeText(el, value) {
        if (el) el.textContent = value == null ? '' : String(value);
    }

    function post(name, data) {
        postWithReply(name, data, null);
    }

    function postWithReply(name, data, callback) {
        try {
            var xhr = new XMLHttpRequest();
            xhr.open('POST', 'https://' + resourceName + '/' + name, true);
            xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
            xhr.timeout = 6000;
            var done = false;
            function finish(response) {
                if (done || !callback) return;
                done = true;
                callback(response);
            }
            xhr.onload = function () {
                var response = {};
                try { response = JSON.parse(xhr.responseText || '{}'); } catch (e) {}
                finish(xhr.status >= 200 && xhr.status < 300 ? response : { ok: false, reason: 'NUI request failed' });
            };
            xhr.onerror = xhr.ontimeout = function () { finish({ ok: false, reason: 'NUI not connected' }); };
            xhr.send(JSON.stringify(data || {}));
        } catch (e) { if (callback) callback({ ok: false, reason: String(e) }); }
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
            var badge = card.querySelector('.tile-state');
            if (badge) {
                var isSelected = !!selected && name === selected.name;
                var isLive = currentStyle ? name === currentStyle : name === 'off';
                badge.textContent = isLive ? (previewActive ? '● LOCAL' : '● LIVE') : (isSelected ? '✓ READY' : 'SELECT');
            }
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
        safeText(activeName, comparing ? 'Comparing against Original GTA' : (previewActive ? 'LOCAL PREVIEW — NOT SYNCED' : (active ? active.name : 'No global style')));
        safeText(strengthReadout, currentStrength.toFixed(2));
        if (compareBtn) compareBtn.classList.toggle('active', comparing);

        if (selected && selected.name === currentStyle && strengthRange) {
            strengthRange.value = currentStrength.toFixed(2);
            updateStrengthReadout();
        }
        updatePreviewControls();
        updateCardStates();
    }

    function updatePreviewControls() {
        if (previewBtn) {
            previewBtn.textContent = previewActive ? 'END PREVIEW' : 'PREVIEW LOCAL';
            previewBtn.classList.toggle('active', previewActive);
        }
        if (previewBanner) previewBanner.classList.toggle('hidden', !previewActive);
        if (captureGalleryBtn) captureGalleryBtn.disabled = !allowGameplayCaptures || galleryRunning || previewActive || momentCapturePending;
        if (saveMomentBtn) saveMomentBtn.disabled = !allowGameplayCaptures || galleryRunning || momentCapturePending;
        if (saveMomentPanelBtn) saveMomentPanelBtn.disabled = !allowGameplayCaptures || galleryRunning || momentCapturePending;
    }

    function createTextNode(tagName, className, text) {
        var el = document.createElement(tagName);
        if (className) el.className = className;
        el.textContent = text == null ? '' : String(text);
        return el;
    }

    function loadGallery() {
        // Preserve in-memory captures if NUI storage is unavailable (or at quota).
        for (var i = 0; i < styles.length; i++) {
            try {
                var url = window.localStorage.getItem(galleryKey + styles[i].name);
                if (url && /^data:image\/(jpeg|webp|png);base64,/.test(url)) {
                    capturedThumbnails[styles[i].name] = url;
                }
            } catch (e) {}
        }
        updateGalleryCount();
    }

    function updateGalleryCount() {
        var total = styles.filter(function (style) { return !style.clear && style.name !== 'off'; }).length;
        var captured = styles.filter(function (style) { return !style.clear && !!capturedThumbnails[style.name]; }).length;
        safeText(galleryCount, captured + ' / ' + total + (galleryPersistent ? ' real captures · saved on this PC' : ' real captures · this session only'));
    }

    function setGalleryStatus(message, error) {
        safeText(galleryStatus, message);
        if (galleryStatus) galleryStatus.classList.toggle('error', error === true);
    }

    function refreshGalleryCard(name) {
        if (!styleGrid) return;
        var cards = styleGrid.children;
        for (var i = 0; i < cards.length; i++) {
            if (cards[i].dataset.style !== name) continue;
            var slot = cards[i].querySelector('.tile-thumbnail');
            if (!slot) return;
            slot.innerHTML = '';
            var url = capturedThumbnails[name];
            if (url) {
                var img = document.createElement('img');
                img.alt = 'Real in-game capture of ' + name;
                img.src = url;
                img.loading = 'lazy';
                slot.appendChild(img);
                slot.appendChild(createTextNode('span', 'thumb-caption', 'IN-GAME CAPTURE'));
                cards[i].classList.add('has-capture');
            } else {
                slot.appendChild(createTextNode('span', 'uncaptured-mark', '◎'));
                slot.appendChild(createTextNode('span', 'uncaptured-label', 'CAPTURE IN GAME'));
                cards[i].classList.remove('has-capture');
            }
            return;
        }
    }

    function endCaptureGallery(message, error) {
        if (galleryTimeout) { clearTimeout(galleryTimeout); galleryTimeout = null; }
        galleryRunning = false;
        galleryWaiting = null;
        galleryQueue = [];
        if (app) app.classList.remove('capture-hidden');
        post('previewStop');
        updatePreviewControls();
        updateGalleryCount();
        if (message) setGalleryStatus(message, error);
    }

    function processGalleryQueue() {
        if (!galleryRunning) return;
        if (!galleryQueue.length) {
            endCaptureGallery(galleryPersistent ? 'Gallery completed. Captures saved on this PC.' : 'Gallery completed for this session. Local image storage is unavailable; the gallery will clear on restart.', false);
            return;
        }
        var style = galleryQueue.shift();
        galleryWaiting = style.name;
        setGalleryStatus('Capturing ' + (galleryTotal - galleryQueue.length) + ' / ' + galleryTotal + ': ' + style.label + ' · keep your game camera still.');
        if (app) app.classList.add('capture-hidden');
        postWithReply('captureThumbnail', { style: style.name, strength: style.strength }, function (result) {
            if (!galleryRunning || galleryWaiting !== style.name) return;
            if (!result || result.ok !== true) {
                endCaptureGallery((result && result.reason) || 'Capture unavailable. Check screenshot-basic.', true);
                return;
            }
            galleryTimeout = setTimeout(function () {
                if (galleryRunning && galleryWaiting === style.name) endCaptureGallery('Screenshot timed out. Check F8 and screenshot-basic.', true);
            }, 10000);
        });
    }

    function beginCaptureGallery() {
        if (galleryRunning || previewActive || !allowGameplayCaptures) return;
        galleryQueue = styles.filter(function (style) { return !style.clear && style.name !== 'off'; });
        if (!galleryQueue.length) return;
        galleryTotal = galleryQueue.length;
        galleryRunning = true;
        updatePreviewControls();
        processGalleryQueue();
    }

    function acceptCaptureResult(data) {
        if (!galleryRunning || galleryWaiting !== data.style) return;
        if (galleryTimeout) { clearTimeout(galleryTimeout); galleryTimeout = null; }
        if (data.error || typeof data.image !== 'string' || data.image.indexOf('data:image/') !== 0) {
            endCaptureGallery(data.error || 'Invalid screenshot from capture resource.', true);
            return;
        }
        var img = new Image();
        img.onload = function () {
            if (!galleryRunning || galleryWaiting !== data.style) return;
            try {
                var canvas = document.createElement('canvas');
                canvas.width = 336; canvas.height = 196;
                var ctx = canvas.getContext('2d');
                var imageRatio = img.width / img.height;
                var targetRatio = canvas.width / canvas.height;
                var cropW = img.width, cropH = img.height, cropX = 0, cropY = 0;
                if (imageRatio > targetRatio) { cropW = img.height * targetRatio; cropX = (img.width - cropW) / 2; }
                else { cropH = img.width / targetRatio; cropY = (img.height - cropH) / 2; }
                ctx.drawImage(img, cropX, cropY, cropW, cropH, 0, 0, canvas.width, canvas.height);
                var thumbnail = canvas.toDataURL('image/jpeg', 0.74);
                try { window.localStorage.setItem(galleryKey + data.style, thumbnail); } catch (e) {
                    galleryPersistent = false;
                }
                capturedThumbnails[data.style] = thumbnail;
                refreshGalleryCard(data.style);
                updateGalleryCount();
                galleryWaiting = null;
                // UI stays hidden between each capture so the screen is never included.
                processGalleryQueue();
            } catch (e) { endCaptureGallery('Unable to process screenshot: ' + e.message, true); }
        };
        img.onerror = function () { endCaptureGallery('Captured image could not be decoded.', true); };
        img.src = data.image;
    }


    // Live Moments are genuine client screenshots + the active local look.
    // They are never sent to the FiveM server, and RECALL only selects a preset.
    function loadMoments() {
        try {
            var raw = window.localStorage.getItem(momentsStorageKey);
            if (raw) {
                var parsed = JSON.parse(raw);
                if (Array.isArray(parsed)) {
                    savedMoments = parsed.filter(function (entry) {
                        return entry && typeof entry.id === 'string' && typeof entry.image === 'string' &&
                            /^data:image\/(jpeg|png|webp);base64,/.test(entry.image);
                    }).slice(0, 10);
                }
            }
        } catch (e) { momentsPersistent = false; }
        renderMoments();
    }

    function storeMoments() {
        try {
            window.localStorage.setItem(momentsStorageKey, JSON.stringify(savedMoments));
            momentsPersistent = true;
        } catch (e) { momentsPersistent = false; }
        renderMoments();
        return momentsPersistent;
    }

    function momentStatusText(text, error) {
        safeText(momentStatus, text);
        if (momentStatus) momentStatus.classList.toggle('error', error === true);
    }

    function showMoments(open) {
        momentPanelOpen = !!open;
        if (momentsPanel) momentsPanel.classList.toggle('hidden', !momentPanelOpen);
        if (!momentPanelOpen && momentLightbox) momentLightbox.classList.add('hidden');
        if (momentPanelOpen) renderMoments();
    }

    function stopMomentCapture(error) {
        momentCapturePending = false;
        momentCaptureContext = null;
        if (momentCaptureTimeout) { clearTimeout(momentCaptureTimeout); momentCaptureTimeout = null; }
        if (app) app.classList.remove('capture-hidden');
        if (error) momentStatusText(error, true);
        updatePreviewControls();
    }

    function formatMomentDate(date) {
        function two(n) { return String(n).padStart(2, '0'); }
        return two(date.getMonth() + 1) + '-' + two(date.getDate()) + '-' + date.getFullYear() +
            ' ' + two(date.getHours()) + ':' + two(date.getMinutes());
    }

    function startMomentCapture() {
        if (galleryRunning || momentCapturePending || !allowGameplayCaptures || comparing || (app && app.classList.contains('hidden'))) return;
        var name = momentNameInput ? momentNameInput.value.trim().slice(0, 48) : '';
        momentCaptureContext = {
            name: name || 'Live Moment ' + (savedMoments.length + 1),
            style: currentStyle || 'off',
            strength: Number(currentStrength || 0),
            date: formatMomentDate(new Date())
        };
        momentCapturePending = true;
        var ticket = ++momentCaptureTicket;
        momentStatusText('Capturing live gameplay — the menu is temporarily hidden...', false);
        updatePreviewControls();
        if (app) app.classList.add('capture-hidden');
        postWithReply('captureMoment', {}, function (result) {
            if (!momentCapturePending || ticket !== momentCaptureTicket) return;
            if (!result || result.ok !== true) {
                stopMomentCapture((result && result.reason) || 'Capture unavailable: start screenshot-basic.');
                return;
            }
            momentCaptureTimeout = setTimeout(function () {
                if (momentCapturePending && ticket === momentCaptureTicket)
                    stopMomentCapture('Live Moment capture timed out. Check screenshot-basic in F8.');
            }, 11000);
        });
    }

    function acceptMomentCaptureResult(data) {
        if (!momentCapturePending) return;
        if (data.error || typeof data.image !== 'string' || data.image.indexOf('data:image/') !== 0) {
            stopMomentCapture(data.error || 'Screenshot service did not return an image.');
            return;
        }
        var context = momentCaptureContext;
        var ticket = momentCaptureTicket;
        var image = new Image();
        image.onload = function () {
            if (!momentCapturePending || ticket !== momentCaptureTicket) return;
            try {
                var canvas = document.createElement('canvas');
                canvas.width = 576; canvas.height = 324;
                var ctx = canvas.getContext('2d');
                var cropW = image.width, cropH = image.height, cropX = 0, cropY = 0;
                if (image.width / image.height > canvas.width / canvas.height) {
                    cropW = image.height * canvas.width / canvas.height; cropX = (image.width - cropW) / 2;
                } else { cropH = image.width * canvas.height / canvas.width; cropY = (image.height - cropH) / 2; }
                ctx.drawImage(image, cropX, cropY, cropW, cropH, 0, 0, canvas.width, canvas.height);
                var frame = canvas.toDataURL('image/jpeg', .72);
                // Bounded localStorage usage; do not silently delete existing captures.
                if (savedMoments.length >= 10) { stopMomentCapture('10 moments saved. Delete one before capturing another.'); showMoments(true); return; }
                savedMoments.unshift({ id: String(Date.now()) + '_' + String(Math.floor(Math.random() * 100000)),
                    name: context.name, date: context.date, style: context.style, strength: context.strength, image: frame });
                var persisted = storeMoments();
                stopMomentCapture();
                if (momentNameInput) momentNameInput.value = '';
                momentStatusText(persisted ? 'Moment saved on this PC. RECALL LOOK selects its mood without synchronizing the server.' :
                    'Moment saved for this session only: local browser storage is full or unavailable.', !persisted);
                showMoments(true);
            } catch (e) { stopMomentCapture('Unable to save screenshot: ' + e.message); }
        };
        image.onerror = function () { stopMomentCapture('Captured moment image could not be decoded.'); };
        image.src = data.image;
    }

    function renderMoments() {
        safeText(momentsCount, String(savedMoments.length));
        if (!momentsList) return;
        momentsList.innerHTML = '';
        if (!savedMoments.length) {
            momentsList.appendChild(createTextNode('p', 'moment-empty', 'No saved moments yet. Position your GTA camera, choose or preview a mood, then press SAVE LIVE MOMENT.'));
            return;
        }
        savedMoments.forEach(function (entry) {
            var tile = document.createElement('article');tile.className = 'moment-item';
            var imageBtn = document.createElement('button');imageBtn.type = 'button';imageBtn.className = 'moment-image-btn';
            imageBtn.title = 'View ' + entry.name;imageBtn.setAttribute('aria-label','View screenshot: ' + entry.name);
            var picture = document.createElement('img');picture.src = entry.image;picture.alt = 'In-game screenshot of ' + entry.name;
            imageBtn.appendChild(picture);
            imageBtn.addEventListener('click', function () {
                if (momentLightboxImage) momentLightboxImage.src = entry.image;
                safeText(momentLightboxTitle, entry.name + ' • ' + entry.date);
                if (momentLightbox) momentLightbox.classList.remove('hidden');
            });
            tile.appendChild(imageBtn);
            tile.appendChild(createTextNode('strong', '', entry.name));
            var linked = findStyle(entry.style);
            tile.appendChild(createTextNode('p','moment-meta',entry.date + ' • ' + (linked ? linked.label : 'Original GTA') + ' @ ' + Number(entry.strength || 0).toFixed(2)));
            var actions = document.createElement('div');actions.className = 'moment-actions';
            var recall = createTextNode('button', '', 'RECALL LOOK');recall.type = 'button';
            recall.addEventListener('click', function () {
                var style = findStyle(entry.style) || findStyle('off');
                if (style) {
                    setSelected(style);
                    if (strengthRange && !style.clear) {
                        strengthRange.value = String(between(Number(entry.strength || style.strength || 0.35), Number(strengthRange.min), Number(strengthRange.max)));
                        updateStrengthReadout();
                    }
                    showMoments(false);
                    setGalleryStatus('Recalled ' + entry.name + '. Press PREVIEW LOCAL to view it; APPLY LOOK changes the server.', false);
                } else momentStatusText('The saved mood is no longer available in this resource.', true);
            });
            var remove = createTextNode('button', 'moment-delete', 'DELETE');remove.type = 'button';
            remove.addEventListener('click', function () {
                if (remove.dataset.confirm !== 'yes') { remove.dataset.confirm = 'yes'; remove.textContent = 'CONFIRM DELETE'; return; }
                savedMoments = savedMoments.filter(function (m) { return m.id !== entry.id; });
                storeMoments();
                momentStatusText('Moment deleted from this PC.', false);
            });
            actions.appendChild(recall);actions.appendChild(remove);tile.appendChild(actions);momentsList.appendChild(tile);
        });
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
                card.dataset.category = String(style.category || 'Other');
                card.dataset.index = String(index + 1);
                card.style.setProperty('--btn-color', style.color || '#43c6e8');
                card.style.setProperty('--btn-rgb', hexToRgb(style.color || '#43c6e8', '67, 198, 232'));
                card.setAttribute('role', 'listitem');
                card.setAttribute('aria-label', 'Select ' + (style.label || style.name));
                var top = document.createElement('span');
                top.className = 'tile-top';
                var thumb = document.createElement('span');
                thumb.className = 'tile-thumbnail';
                thumb.setAttribute('aria-hidden', 'true');
                top.appendChild(thumb);
                top.appendChild(createTextNode('span', 'tile-state', 'SELECT'));
                card.appendChild(top);
                card.appendChild(createTextNode('strong', 'tile-title', style.label || style.name));
                card.appendChild(createTextNode('small', 'card-meta', (style.category || 'Other') + ' / ' + (style.intensity || 'Medium')));
                if (style.experimental) card.appendChild(createTextNode('span', 'experimental-tag', 'BETA'));
                card.addEventListener('click', function () { setSelected(style); });
                // A double click must never apply globally without explicit confirmation.
                card.addEventListener('dblclick', function () { setSelected(style); });
                styleGrid.appendChild(card);
                refreshGalleryCard(style.name);
            })(styles[i], i);
        }
        renderFilters();
        updateCardStates();
    }

    function openMenu(data) {
        data = data || {};
        styles = Object.prototype.toString.call(data.styles) === '[object Array]' ? data.styles : [];
        closeAfterApply = data.closeAfterApply === true;
        if (!layoutInitialized) {
            var stored = normalizeLayouts(data.uiLayout || localLayout() || {});
            viewMode = stored.view;
            layouts.phone = stored.phone;
            layouts.studio = stored.studio;
            layout = layouts[viewMode];
            layoutInitialized = true;
        }
        allowGameplayCaptures = data.allowGameplayCaptures !== false;
        document.body.classList.toggle('hide-window-labels', data.showWindowLabels === false);
        safeText(title, data.title || 'Visual Director');
        safeText(modeText, String(data.mode || 'sync').toUpperCase());

        loadGallery();
        loadMoments();
        showMoments(false);
        renderStyles();
        previewActive = false;
        previewStyle = null;
        currentStyle = data.currentStyle || null;
        currentStrength = Number(data.currentStrength || 0);
        setSelected(findStyle(currentStyle) || findStyle('off') || findStyle('gummy_air') || styles[0]);
        setState(currentStyle, currentStrength, false);

        if (bootNotice) bootNotice.style.display = 'none';
        if (app) {
            app.classList.remove('hidden');
            app.classList.toggle('studio-mode', viewMode === 'studio');
            app.setAttribute('aria-hidden', 'false');
            if (viewModeBtn) viewModeBtn.textContent = viewMode === 'studio' ? 'PHONE VIEW' : 'STUDIO VIEW';
            positionPhone();
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
        if (galleryRunning) endCaptureGallery('Capture cancelled.', false);
        if (momentCapturePending) { momentCaptureTicket++; stopMomentCapture(); }
        showMoments(false);
        if (previewActive) { post('previewStop'); previewActive = false; }
        stopMove();
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
        if (galleryRunning) return;
        if (previewActive) { post('previewStop'); previewActive = false; }
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
        if (galleryRunning) return;
        if (previewActive) { post('previewStop'); previewActive = false; }
        post('clearStyle');
    }

    function togglePreview() {
        if (!selected || galleryRunning) return;
        endCompare();
        if (previewActive) {
            postWithReply('previewStop', {}, function () {});
            previewActive = false;
            previewStyle = null;
            setState(currentStyle, currentStrength, false);
        } else {
            var name = selected.clear === true ? 'off' : selected.name;
            var strength = Number(strengthRange ? strengthRange.value : selected.strength || 0.35);
            postWithReply('previewStart', { style: name, strength: strength }, function (response) {
                if (!response || !response.ok) setGalleryStatus('Local preview unavailable. Check your F8 console.', true);
            });
        }
        updatePreviewControls();
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
            if (galleryRunning) endCaptureGallery('Capture cancelled.', false);
            if (momentCapturePending) { momentCaptureTicket++; stopMomentCapture(); }
            showMoments(false);
            previewActive = false;
            if (drag) stopMove();
            if (app) { app.classList.add('hidden'); app.setAttribute('aria-hidden', 'true'); }
            if (bootNotice) bootNotice.style.display = 'none';
            return;
        }
        if (data.action === 'state') {
            previewActive = data.previewActive === true;
            previewStyle = data.previewStyle || null;
            setState(data.currentStyle, Number(data.currentStrength || 0), data.comparing === true);
            return;
        }
        if (data.action === 'worldOverlay') { setWorldOverlay(data); return; }
        if (data.action === 'captureResult') { acceptCaptureResult(data); return; }
        if (data.action === 'momentCaptureResult') { acceptMomentCaptureResult(data); return; }
        if (data.action === 'boot' && bootNotice) bootNotice.style.display = 'block';
    });

    window.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' || event.keyCode === 27) {
            if (momentLightbox && !momentLightbox.classList.contains('hidden')) { momentLightbox.classList.add('hidden'); return; }
            if (momentPanelOpen) { showMoments(false); return; }
            closeMenu();
            return;
        }
        if (event.key === ' ' && compareBtn && document.activeElement === compareBtn) beginCompare();
    });
    window.addEventListener('keyup', function (event) {
        if (event.key === ' ' && comparing) endCompare();
    });
    window.addEventListener('blur', endCompare);

    if (strengthRange) strengthRange.addEventListener('input', updateStrengthReadout);
    if (viewModeBtn) viewModeBtn.addEventListener('click', function () { setViewMode(viewMode === 'studio' ? 'phone' : 'studio'); });
    if (previewBtn) previewBtn.addEventListener('click', togglePreview);
    if (captureGalleryBtn) captureGalleryBtn.addEventListener('click', beginCaptureGallery);
    if (saveMomentBtn) saveMomentBtn.addEventListener('click', startMomentCapture);
    if (saveMomentPanelBtn) saveMomentPanelBtn.addEventListener('click', startMomentCapture);
    if (openMomentsBtn) openMomentsBtn.addEventListener('click', function () { showMoments(true); });
    if (closeMomentsBtn) closeMomentsBtn.addEventListener('click', function () { showMoments(false); });
    if (closeMomentLightboxBtn) closeMomentLightboxBtn.addEventListener('click', function () { if (momentLightbox) momentLightbox.classList.add('hidden'); });
    if (categoryPrevBtn) categoryPrevBtn.addEventListener('click', function () { scrollCategoryStrip(-1); });
    if (categoryNextBtn) categoryNextBtn.addEventListener('click', function () { scrollCategoryStrip(1); });
    if (categoryFilters) {
        categoryFilters.addEventListener('scroll', updateCategoryArrows, { passive: true });
        categoryFilters.addEventListener('wheel', function (event) {
            if (categoryFilters.scrollWidth <= categoryFilters.clientWidth + 2) return;
            if (Math.abs(event.deltaY) >= Math.abs(event.deltaX)) {
                categoryFilters.scrollLeft += event.deltaY;
                event.preventDefault();
            }
        }, { passive: false });
    }
    if (moveHandle) moveHandle.addEventListener('pointerdown', beginMove);
    window.addEventListener('pointermove', updateMove);
    window.addEventListener('pointerup', stopMove);
    window.addEventListener('pointercancel', stopMove);
    window.addEventListener('resize', function () { positionPhone(); updateCategoryArrows(); });
    if (sizeDownBtn) sizeDownBtn.addEventListener('click', function () { adjustPhoneSize(-0.08); });
    if (sizeUpBtn) sizeUpBtn.addEventListener('click', function () { adjustPhoneSize(0.08); });
    if (resetLayoutBtn) resetLayoutBtn.addEventListener('click', function () {
        layout = { x: 0.5, y: 0.5, scale: 1 };
        layouts[viewMode] = layout;
        positionPhone();
        saveLayout();
    });
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
