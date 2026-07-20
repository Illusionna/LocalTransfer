(function() {
    var ws;
    var delay = 1000;

    function connect() {
        var protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
        ws = new WebSocket(protocol + location.host + '/api/watch/');

        ws.addEventListener('open', function() {
            delay = 1000;
        });

        ws.addEventListener('message', function(ev) {
            try {
                var message = JSON.parse(ev.data);
                if (message.type === 'changed' && typeof UpdateFileList === 'function') {
                    UpdateFileList(typeof CURRENT_DIR !== 'undefined' ? CURRENT_DIR : '.');
                }
            } catch (e) {}
        });

        ws.addEventListener('close', function() {
            setTimeout(connect, delay);
            delay = Math.min(delay * 2, 10000);
        });

        ws.addEventListener('error', function() {
            ws.close();
        });
    }

    connect();
})();
