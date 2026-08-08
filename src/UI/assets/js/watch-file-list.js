(function() {
    var ws;
    var delay = 1000;
    var reconnect_timer;
    var stable_timer;
    var stopped = false;

    function scheduleReconnect() {
        if (stopped || reconnect_timer) return;
        reconnect_timer = setTimeout(function() {
            reconnect_timer = undefined;
            connect();
        }, delay);
        delay = Math.min(delay * 2, 10000);
    }

    function connect() {
        if (ws && (ws.readyState === WebSocket.CONNECTING || ws.readyState === WebSocket.OPEN)) return;
        if (stopped || document.hidden || !navigator.onLine) {
            scheduleReconnect();
            return;
        }
        var protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
        var socket = new WebSocket(protocol + location.host + '/api/watch/');
        ws = socket;

        socket.addEventListener('open', function() {
            if (ws !== socket) return;
            clearTimeout(stable_timer);
            stable_timer = setTimeout(function() {
                delay = 1000;
            }, 30000);
        });

        socket.addEventListener('message', function(ev) {
            if (ws !== socket) return;
            try {
                var message = JSON.parse(ev.data);
                if (message.type === 'changed' && typeof UpdateFileList === 'function') {
                    UpdateFileList(typeof CURRENT_DIR !== 'undefined' ? CURRENT_DIR : '.');
                }
            } catch (e) {}
        });

        socket.addEventListener('close', function() {
            if (ws !== socket) return;
            clearTimeout(stable_timer);
            scheduleReconnect();
        });

        socket.addEventListener('error', function() {
            socket.close();
        });
    }

    document.addEventListener('visibilitychange', function() {
        if (!document.hidden && (!ws || ws.readyState === WebSocket.CLOSED)) {
            clearTimeout(reconnect_timer);
            reconnect_timer = undefined;
            connect();
        }
    });
    window.addEventListener('online', function() {
        clearTimeout(reconnect_timer);
        reconnect_timer = undefined;
        connect();
    });
    window.addEventListener('beforeunload', function() {
        stopped = true;
        clearTimeout(reconnect_timer);
        clearTimeout(stable_timer);
        if (ws) ws.close();
    });

    connect();
})();
