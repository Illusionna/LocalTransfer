const search_dialog = document.querySelector('.search-dialog');

document.querySelector('.nav-item img[src="/UI/assets/images/search.svg"]').parentElement.addEventListener('click', () => {
    let search_state = null;
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

    const search = async (offset, append) => {
        if (!search_state || search_state.loading) return;
        search_state.loading = true;
        const searching = document.getElementById('searching');
        const load_more = document.getElementById('search-dialog-load-more');
        if (load_more) load_more.disabled = true;
        searching.textContent = append ? '正在加载更多结果...' : '正在搜索中...';

        try {
            const start_time = Date.now();
            const response = await fetch('/api/search-file/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    Path: search_state.paths,
                    Target: search_state.target,
                    CurrentDir: search_state.current_dir,
                    Limit: 50,
                    Offset: offset,
                })
            });
            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }
            const json = await response.json();
            const results = Array.isArray(json) ? json : (json.Results || []);
            const duration = Date.now() - start_time;
            const duration_text = duration >= 1000 ? `${(duration / 1000).toFixed(2)} 秒` : `${duration} 毫秒`;
            search_state.result_count += results.length;
            search_state.next_offset = json.NextOffset;

            if (search_state.result_count === 0) {
                searching.textContent = '没有找到相关结果，请尝试其他搜索？';
            } else {
                searching.textContent = json.Truncated ? '搜索达到扫描上限，请缩小范围或关键字后重试。' : '';
            }
            document.querySelector('.search-dialog-result-information-count').innerHTML = `耗时 ${duration_text}, 已加载 <span>${search_state.result_count}</span> 个结果.`;
            UpdateSearchDialog(results, append, search_state.current_dir);
            update_load_more_button();
        } catch (error) {
            alert("搜索文件异常: " + error.message);
            searching.textContent = '';
        } finally {
            search_state.loading = false;
            const button = document.getElementById('search-dialog-load-more');
            if (button) button.disabled = false;
        }
    };

    const update_load_more_button = () => {
        document.getElementById('search-dialog-load-more')?.remove();
        if (search_state.next_offset === null || search_state.next_offset === undefined) return;

        const button = document.createElement('button');
        button.id = 'search-dialog-load-more';
        button.type = 'button';
        button.className = 'search-dialog-confirm-button';
        button.textContent = '加载更多结果';
        button.addEventListener('click', () => search(search_state.next_offset, true));
        document.getElementById('search-dialog-results').after(button);
    };

    document.getElementById('search-dialog-confirm-button-t').addEventListener('click', () => {
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

        search_state = {
            target: target.value,
            paths: selected_paths,
            // Keep result links rooted in the directory that was searched.
            current_dir: CURRENT_DIR,
            result_count: 0,
            next_offset: null,
            loading: false,
        };
        document.querySelector('.search-dialog-result-information-count').innerHTML = `找到 <span>0</span> 个结果`;
        const results_div = document.getElementById('search-dialog-results');
        results_div.innerHTML = '';
        document.getElementById('search-dialog-load-more')?.remove();
        search(0, false);
    });
});


function UpdateSearchDialog(data, append = false, current_dir = '.') {
    const results_div = document.getElementById('search-dialog-results');

    if (!append) results_div.innerHTML = '';

    data.forEach(item => {
        const div = document.createElement('div');
        div.className = 'search-dialog-separator-line';

        const path_div = document.createElement('div');
        path_div.className = 'search-dialog-result-item-path';
        path_div.textContent = item.Path;
        path_div.title = '点击打开';
        path_div.style.cursor = 'pointer';
        path_div.tabIndex = 0;
        path_div.setAttribute('role', 'link');
        const open_result = () => {
            const link = document.createElement('a');
            link.href = BuildShareUrl(current_dir, item.Path);
            link.target = '_blank';
            link.rel = 'noopener';
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        };
        path_div.addEventListener('click', open_result);
        path_div.addEventListener('keydown', event => {
            if (event.key === 'Enter' || event.key === ' ') {
                event.preventDefault();
                open_result();
            }
        });
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
