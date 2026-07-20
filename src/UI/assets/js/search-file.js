const search_dialog = document.querySelector('.search-dialog');

document.querySelector('.nav-item img[src="/UI/assets/images/search.svg"]').parentElement.addEventListener('click', () => {
    const search_dialog_status = search_dialog.style.display === 'block';
    search_dialog.style.display = search_dialog_status ? 'none' : 'block';

    if (!search_dialog_status) {
        search_dialog.innerHTML = `
            <div style="display: flex;" id="search-dialog-input-t">
                <input type="text" class="search-dialog-input" placeholder=">>> search?">
                <button type="button" class="search-dialog-confirm-button" id="search-dialog-confirm-button-t">搜索</button>
            </div>
    
            <div style="margin-top: 2rem;">
                <div class="search-dialog-result-information">
                    <div class="search-dialog-result-information-header">搜索结果</div>
                    <div class="search-dialog-result-information-count">找到 <span>0</span> 个结果</div>
                </div>
            </div>
    
            <p id="searching"></p>
    
            <div id="search-dialog-results"></div>
        `;
    }

    document.getElementById('search-dialog-confirm-button-t').addEventListener('click', async () => {
        const target = document.getElementById('search-dialog-input-t').querySelector('input[type="text"]');
        const selected_paths = Array.from(
            document.querySelectorAll('.file-item input[type="checkbox"]:checked'),
            checkbox => checkbox.dataset.path
        );

        if (target.value.trim().length === 0) {
            alert('输入有效搜索内容😊');
            target.value = '';
            return;
        }
        if (selected_paths.length === 0) {
            alert('请勾选需要搜索的文件或目录😊');
            return;
        }

        document.querySelector('.search-dialog-result-information-count').innerHTML = `找到 <span>0</span> 个结果`
        const results_div = document.getElementById('search-dialog-results');
        results_div.innerHTML = '';
        document.getElementById('searching').innerHTML = '正在搜索中...';

        try {
            const start_time = Date.now();
            const response = await fetch('/api/search-file/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    Path: selected_paths,
                    Target: target.value,
                    CurrentDir: CURRENT_DIR
                })
            });
            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }
            const json = await response.json();
            const duration = Date.now() - start_time;
            const duration_text = duration >= 1000 ? `${(duration / 1000).toFixed(2)} 秒` : `${duration} 毫秒`;
            if (json.length === 0) {
                document.getElementById('searching').innerHTML = '没有找到相关结果，请尝试其他搜索？';
            } else {
                document.getElementById('searching').innerHTML = '';
            }
            document.querySelector('.search-dialog-result-information-count').innerHTML = `耗时 ${duration_text}, 找到 <span>${json.length}</span> 个结果.`
            UpdateSearchDialog(json);
        } catch (error) {
            alert("搜索文件异常: " + error.message);
        }
    });
});


function UpdateSearchDialog(data) {
    const results_div = document.getElementById('search-dialog-results');

    results_div.innerHTML = ''; 

    data.forEach(item => {
        const div = document.createElement('div');
        div.className = 'search-dialog-separator-line';

        const path_div = document.createElement('div');
        path_div.className = 'search-dialog-result-item-path';
        path_div.textContent = item.Path;
        div.appendChild(path_div);

        if (item.Description) {
            const description_div = document.createElement('div');
            description_div.className = 'search-dialog-result-item-description';
            description_div.textContent = item.Description;
            div.append(description_div);
        }

        if ('Image' in item) {
            const image_div = document.createElement('div');
            image_div.className = 'search-dialog-result-item-image';
            image_div.innerHTML = `
                <img class="search-dialog-result-image-limit" src="data:image/${item.Path.substring(item.Path.lastIndexOf('.') + 1)};base64,${item.Image}" alt="Oops?">
            `;
            div.appendChild(image_div);
        }
        results_div.appendChild(div);
    });
}
