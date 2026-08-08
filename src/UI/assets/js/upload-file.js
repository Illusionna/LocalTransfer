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

    async function TraverseDirectoryTree(entry, path='') {
        if (entry.isFile) {
            const file = await ReadEntryFile(entry);
            return [{ file: file, path: path + file.name }];
        }

        if (entry.isDirectory) {
            const entries = await ReadDirectoryEntries(entry.createReader());
            const files = await Promise.all(entries.map(child => TraverseDirectoryTree(child, path + entry.name + '/')));
            return files.flat();
        }

        return [];
    }

    drop_zone.addEventListener('drop', async (e) => {
        e.preventDefault();
        drop_zone.classList.remove('dragover');
        const entries = Array.from(e.dataTransfer.items)
            .map(item => item.webkitGetAsEntry())
            .filter(Boolean);

        try {
            drop_zone_upload_button.querySelector('span').textContent = '正在读取文件夹...';
            const nested_files = await Promise.all(entries.map(entry => TraverseDirectoryTree(entry)));
            const files = nested_files.flat();
            HandleUploadFile(files);
        } catch (error) {
            alert("读取文件夹异常：" + error.message);
        }
    });

    document.querySelector('.upload-dialog-cancel').addEventListener('click', () => {
        if (upload_in_progress) return;
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
        let completed_size = 0;
        const failures = [];
        upload_in_progress = true;
        try {
            progress_container.style.display = 'block';
            progress_text.style.display = 'block';
            progress_bar.style.width = '0%';
            progress_bar.textContent = '0%';
            ok_button.disabled = true;
            cancel_button.disabled = true;

            // The server limit is per request, so send one file at a time.
            for (const item of selected_upload_files) {
                const response = await UploadOneFile(item, upload_dir, (loaded) => {
                    const current = completed_size + loaded;
                    const percent = total_size === 0 ? 100 : Math.min(100, Math.round(current / total_size * 100));
                    progress_bar.style.width = percent + '%';
                    progress_bar.textContent = percent + '%';
                    progress_text.textContent = `已上传 ${FormatFileSize(current)} / ${FormatFileSize(total_size)}`;
                });
                completed_size += item.file.size;

                if (response.results.length > 0) {
                    response.results.filter(result => !result.Success).forEach(result => failures.push(result));
                } else {
                    failures.push({ Path: item.path, Error: response.message || `HTTP ${response.status}` });
                }
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
            ok_button.disabled = false;
            cancel_button.disabled = false;
        }
    });

    function UploadOneFile(item, upload_dir, on_progress) {
        return new Promise((resolve, reject) => {
            const form_data = new FormData();
            form_data.append('CurrentDir', upload_dir);
            form_data.append('RelativePath', item.path);
            form_data.append('File', item.file, item.file.name);

            const xhr = new XMLHttpRequest();
            xhr.upload.addEventListener('progress', event => on_progress(event.loaded));
            xhr.onerror = () => reject(new Error(`${item.path}: 网络连接中断`));
            xhr.onabort = () => reject(new Error(`${item.path}: 上传已取消`));
            xhr.onload = () => {
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
