const std_search_dialog = document.querySelector('.std-search-dialog');

document.querySelector('.nav-item img[src="/UI/assets/images/search.svg"]').parentElement.addEventListener('click', () => {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {
            Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`
        };
    });
    if (selected_files.length === 0) {
        alert('选择搜索范围哦😊');
        return;
    }

    std_search_dialog.style.display = 'block';
    std_search_dialog.innerHTML = `
        <div class="std-search-dialog-nav">
            <div class="std-search-dialog-nav-top">
                <div class="std-search-dialog-nav-top-item">
                    <span>标准搜索</span>
                    <div class="std-search-dialog-switch-slide">
                        <input type="checkbox" id="standard-search" hidden checked>
                        <label for="standard-search" class="std-search-dialog-switch-slide-label"></label>
                    </div>
                </div>

                <div class="std-search-dialog-nav-top-item">
                    <span>关键词搜索</span>
                    <div class="std-search-dialog-switch-slide">
                        <input type="checkbox" id="keyword-search" hidden>
                        <label for="keyword-search" class="std-search-dialog-switch-slide-label"></label>
                    </div>
                </div>

                <div class="std-search-dialog-nav-top-item"></div>

                <div class="std-search-dialog-nav-top-item">
                    <svg t="1738999864063" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="4348" xmlns:xlink="http://www.w3.org/1999/xlink" width="200" height="200"><path d="M601.1 513.2l308.6-308.6c24.3-24.3 24.3-63.8 0-88.2-24.3-24.3-63.8-24.3-88.2 0L513 425.1 204.4 116.6c-24.3-24.3-63.8-24.3-88.2 0-24.3 24.3-24.3 63.8 0 88.2l308.6 308.5-308.6 308.5c-24.3 24.3-24.3 63.8 0 88.2 24.3 24.3 63.8 24.3 88.2 0L513 601.4 821.6 910c24.3 24.3 63.8 24.3 88.2 0 24.3-24.3 24.3-63.8 0-88.2L601.1 513.2z" p-id="4349"></path></svg>
                </div>
            </div>
            <p></p>
            <div class="std-search-dialog-nav-bottom">
                <input id="std-search" type="text" placeholder=">>> Search..." />
                <button id="std-search-dialog-ok">OK</button>
                <span></span>
            </div>
        </div>

        <div class="std-search-dialog-list">
            <ol></ol>
        </div>
    `;

    document.getElementById('std-search-dialog-ok').addEventListener('click', async () => {
        const standard_search_status = document.getElementById('standard-search').checked;
        const keyword_search_status = document.getElementById('keyword-search').checked;

        if ((standard_search_status || keyword_search_status) === false) {
            alert("至少选择一种搜索算法😊");
            return;
        }

        const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
        const selected_files = Array.from(selected_checkboxs).map(c => {
            const file_name = c.parentElement.querySelector('.file-name').textContent;
            return {
                Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`,
                Target: document.getElementById('std-search').value,
                StandardSearchStatus: standard_search_status,
                KeywordSearchStatus: keyword_search_status
            };
        });
        if (selected_files.length === 0) {
            alert('请选择复选框, 以确定搜索范围😊');
            return;
        }

        try {
            const response = await fetch('/api/search-file/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(selected_files)
            });
            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }

            const json = await response.json();

            const data = json.data;

            document.querySelector('.std-search-dialog-nav-bottom span').textContent = `${json.time}`
        

            const ol = document.querySelector('.std-search-dialog-list ol');
            while (ol.firstChild) {
                ol.removeChild(ol.firstChild);
            }

            if (data && data.length > 0) {
                data.forEach(item => {
                    const li = document.createElement('li');
                    li.innerHTML = `<a href="/api/share/${item}" target="_blank">${item}</a>`;
                    ol.appendChild(li);
                });
            } else {
                const li = document.createElement('li');
                li.innerHTML = `<a>[NULL] ---- (未搜索到结果)</a>`;
                ol.appendChild(li);
            }
        } catch (error) {
            alert("搜索文件异常: " + error.message);
        }
    });

    document.querySelector('.std-search-dialog-nav-top-item svg').addEventListener('click', () => {
        std_search_dialog.style.display = 'none';
    });
});