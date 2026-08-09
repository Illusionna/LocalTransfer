const upload_dialog = document.querySelector('.upload-dialog');


document.querySelector('.nav-item img[src="/UI/assets/images/upload.svg"]').parentElement.addEventListener('click', CreateUploadDialog);


function CreateUploadDialog() {
    upload_dialog.style.display = 'block';
    const content = document.querySelector('.upload-dialog');
    content.innerHTML = `
        <div class="upload-dialog-content">
            <div class="drop-zone">
                <div class="drop-zone-content">
                    <input type="file" multiple style="display: none;" id="drop-zone-file">
                    <button class="drop-zone-upload-button">
                        <div style="margin-bottom: -10px;">
                            <img src="/UI/assets/images/upload.svg">
                        </div>
                        <span>拖拽文件（夹）或选择文件</span>
                    </button>
                </div>
            </div>
            <button class="upload-dialog-cancel">取消</button>
            <button class="upload-dialog-ok">确定</button>
            <div class="upload-progress-container" style="display: none; width: 100%; margin: 10px 0;">
                <div class="upload-progress-bar" style="width: 0%; height: 20px; background-color: #4CAF50; text-align: center; line-height: 20px; color: white; border-radius: 5px;"></div>
            </div>
            <div class="upload-progress-text" style="display: none; text-align: center; margin: 5px 0;"></div>
        </div>
    `;

    const drop_zone = document.querySelector('.drop-zone');
    const drop_zone_file = document.getElementById('drop-zone-file');
    const drop_zone_upload_button = document.querySelector('.drop-zone-upload-button');
    const progress_container = document.querySelector('.upload-progress-container');
    const progress_bar = document.querySelector('.upload-progress-bar');
    const progress_text = document.querySelector('.upload-progress-text');
    let selected_upload_files = [];
    let upload_in_progress = false;
    let upload_cancelled = false;
    let active_upload_request = null;

    function HandleUploadFile(files) {
        selected_upload_files = Array.from(files).map(item => {
            if (item.file && item.path) return item;
            return { file: item, path: item.webkitRelativePath || item.name };
        }).filter(item => item.path);
        drop_zone_file.value = '';
        drop_zone_upload_button.querySelector('span').style.whiteSpace = 'nowrap';
        drop_zone_upload_button.querySelector('span').textContent = `待上传 ${selected_upload_files.length} 个文件.`;
    }

    drop_zone_upload_button.addEventListener('click', () => {drop_zone_file.click()});

    drop_zone_file.addEventListener('change', (e) => {HandleUploadFile(e.target.files)});

    drop_zone.addEventListener('dragover', (e) => {
        e.preventDefault();
        drop_zone.classList.add('dragover');
    });

    drop_zone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        drop_zone.classList.remove('dragover');
    });

    function ReadDirectoryEntries(reader) {
        return new Promise((resolve, reject) => {
            const entries = [];

            function readBatch() {
                reader.readEntries((batch) => {
                    if (batch.length === 0) {
                        resolve(entries);
                        return;
                    }
                    entries.push(...batch);
                    readBatch();
                }, reject);
            }

            readBatch();
        });
    }

    function ReadEntryFile(entry) {
        return new Promise((resolve, reject) => {
            entry.file(resolve, reject);
        });
    }

    async function TraverseDirectoryTree(entries) {
        const files = [];
        const pending = entries.map(entry => ({ entry: entry, path: '' }));
        let offset = 0;

        while (offset < pending.length) {
            const batch = pending.slice(offset, offset + 8);
            offset += batch.length;
            const results = await Promise.all(batch.map(async item => {
                if (item.entry.isFile) {
                    const file = await ReadEntryFile(item.entry);
                    return { file: file, path: item.path + file.name };
                }
                if (item.entry.isDirectory) {
                    const children = await ReadDirectoryEntries(item.entry.createReader());
                    return children.map(child => ({ entry: child, path: item.path + item.entry.name + '/' }));
                }
                return null;
            }));

            for (const result of results) {
                if (Array.isArray(result)) {
                    pending.push(...result);
                } else if (result) {
                    files.push(result);
                }
            }
        }
        return files;
    }

    drop_zone.addEventListener('drop', async (e) => {
        e.preventDefault();
        drop_zone.classList.remove('dragover');
        const items = Array.from(e.dataTransfer.items).filter(item => item.kind === 'file');
        const entries = [];
        const files = [];
        for (const item of items) {
            const get_entry = item.getAsEntry || item.webkitGetAsEntry;
            if (typeof get_entry === 'function') {
                const entry = get_entry.call(item);
                if (entry) entries.push(entry);
            } else {
                const file = item.getAsFile();
                if (file) files.push({ file: file, path: file.name });
            }
        }

        try {
            drop_zone_upload_button.querySelector('span').textContent = '正在读取文件夹...';
            files.push(...await TraverseDirectoryTree(entries));
            HandleUploadFile(files);
        } catch (error) {
            alert("读取文件夹异常：" + error.message);
        }
    });

    document.querySelector('.upload-dialog-cancel').addEventListener('click', () => {
        if (upload_in_progress) {
            upload_cancelled = true;
            progress_text.textContent = '正在取消上传...';
            document.querySelector('.upload-dialog-cancel').disabled = true;
            if (active_upload_request) active_upload_request.abort();
            return;
        }
        upload_dialog.style.display = 'none';
    });

    document.querySelector('.upload-dialog-ok').addEventListener('click', async () => {
        if (upload_in_progress) return;
        if (selected_upload_files.length === 0) {
            alert('请上传文件😊');
            return;
        }

        const ok_button = document.querySelector('.upload-dialog-ok');
        const cancel_button = document.querySelector('.upload-dialog-cancel');
        const upload_dir = CURRENT_DIR;
        const total_size = selected_upload_files.reduce((sum, item) => sum + item.file.size, 0);
        const upload_batches = CreateUploadBatches(selected_upload_files);
        let completed_size = 0;
        const failures = [];
        upload_in_progress = true;
        upload_cancelled = false;
        try {
            progress_container.style.display = 'block';
            progress_text.style.display = 'block';
            progress_bar.style.width = '0%';
            progress_bar.textContent = '0%';
            ok_button.disabled = true;
            cancel_button.disabled = false;

            for (const batch of upload_batches) {
                if (upload_cancelled) break;
                const batch_size = batch.reduce((sum, item) => sum + item.file.size, 0);
                let response;
                try {
                    response = await UploadFileBatch(batch, upload_dir, (loaded) => {
                        const current = Math.min(total_size, completed_size + Math.min(loaded, batch_size));
                        const percent = total_size === 0 ? 100 : Math.min(100, Math.round(current / total_size * 100));
                        progress_bar.style.width = percent + '%';
                        progress_bar.textContent = percent + '%';
                        progress_text.textContent = `已上传 ${FormatFileSize(current)} / ${FormatFileSize(total_size)}`;
                    });
                } catch (error) {
                    if (upload_cancelled) break;
                    batch.forEach(item => failures.push({ Path: item.path, Error: error.message }));
                    completed_size += batch_size;
                    continue;
                }
                completed_size += batch_size;

                if (response.results.length > 0) {
                    response.results.filter(result => !result.Success).forEach(result => failures.push(result));
                } else {
                    batch.forEach(item => failures.push({ Path: item.path, Error: response.message || `HTTP ${response.status}` }));
                }
            }

            if (upload_cancelled) {
                progress_text.textContent = '上传已取消';
                ClearFileSelections();
                selected_upload_files = [];
                await UpdateFileList(CURRENT_DIR);
                upload_dialog.style.display = 'none';
                return;
            }

            progress_bar.style.width = '100%';
            progress_bar.textContent = '100%';
            progress_text.textContent = failures.length === 0 ? '上传成功' : '部分文件上传失败';
            ClearFileSelections();
            await UpdateFileList(CURRENT_DIR);
            if (failures.length > 0) {
                alert(`上传未全部成功：\n${failures.map(result => `${result.Path}: ${result.Error}`).join('\n')}`);
            }
            selected_upload_files = [];
            upload_dialog.style.display = 'none';
        } catch (error) {
            progress_text.textContent = '上传失败，可以直接重试';
            alert("上传文件异常：" + error.message);
        } finally {
            upload_in_progress = false;
            active_upload_request = null;
            ok_button.disabled = false;
            cancel_button.disabled = false;
        }
    });

    function CreateUploadBatches(items) {
        const batches = [];
        let batch = [];
        let batch_size = 0;

        for (const item of items) {
            if (item.file.size > 1024 * 1024) {
                if (batch.length > 0) batches.push(batch);
                batches.push([item]);
                batch = [];
                batch_size = 0;
                continue;
            }
            if (batch.length > 0 && (batch.length >= 64 || batch_size + item.file.size > 16 * 1024 * 1024)) {
                batches.push(batch);
                batch = [];
                batch_size = 0;
            }
            batch.push(item);
            batch_size += item.file.size;
        }
        if (batch.length > 0) batches.push(batch);
        return batches;
    }

    function UploadFileBatch(items, upload_dir, on_progress) {
        return new Promise((resolve, reject) => {
            const form_data = new FormData();
            form_data.append('CurrentDir', upload_dir);
            items.forEach(item => {
                form_data.append('RelativePath', item.path);
                form_data.append('File', item.file, item.file.name);
            });

            const xhr = new XMLHttpRequest();
            active_upload_request = xhr;
            xhr.upload.addEventListener('progress', event => on_progress(event.loaded));
            xhr.onerror = () => {
                if (active_upload_request === xhr) active_upload_request = null;
                reject(new Error('网络连接中断'));
            };
            xhr.onabort = () => {
                if (active_upload_request === xhr) active_upload_request = null;
                reject(new Error('上传已取消'));
            };
            xhr.onload = () => {
                if (active_upload_request === xhr) active_upload_request = null;
                let results = [];
                try {
                    const parsed = JSON.parse(xhr.responseText);
                    if (Array.isArray(parsed)) results = parsed;
                } catch (_) {}
                resolve({
                    ok: xhr.status >= 200 && xhr.status < 300,
                    status: xhr.status,
                    results: results,
                    message: results.length === 0 ? xhr.responseText : ''
                });
            };
            xhr.open('POST', '/api/upload-file/', true);
            xhr.send(form_data);
        });
    }

    function FormatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
}
