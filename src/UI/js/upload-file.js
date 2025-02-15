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
        </div>
    `;

    const drop_zone = document.querySelector('.drop-zone');
    const drop_zone_file = document.getElementById('drop-zone-file');
    const drop_zone_upload_button = document.querySelector('.drop-zone-upload-button');
    let selected_upload_files = [];

    function HandleUploadFile(files) {
        selected_upload_files = Array.from(files);
        selected_upload_files.forEach(file => {
            if (!file.filepath) {
                const full_path = file.webkitRelativePath || file.name;
                file.filepath = full_path;
            }
        });
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

    drop_zone.addEventListener('drop', (e) => {
        e.preventDefault();
        drop_zone.classList.remove('dragover');
        const items = e.dataTransfer.items;
        const files = [];

        function TraverseDirectoryTree(item, path='') {
            if (item.isFile) {
                item.file(file => {
                    file.filepath = path + file.name;
                    files.push(file);
                });
            } else if (item.isDirectory) {
                const dir_reader = item.createReader();
                dir_reader.readEntries(entries => {
                    entries.forEach(entry => {
                        TraverseDirectoryTree(entry, path + item.name + '/');
                    });
                });
            } else {
                // ...
            }
        }

        for (let item of items) {
            const entry = item.webkitGetAsEntry();
            if (entry) {
                TraverseDirectoryTree(entry);
            }
        }

        setTimeout(() => {
            HandleUploadFile(files);
        }, 100);
    });

    document.querySelector('.upload-dialog-cancel').addEventListener('click', () => {
        upload_dialog.style.display = 'none';
    });

    document.querySelector('.upload-dialog-ok').addEventListener('click', async () => {
        if (selected_upload_files.length === 0) {
            alert('请上传文件😊');
            return;
        }

        const form_data = new FormData();
        selected_upload_files.forEach((file) => {
            if (file.filepath) {
                form_data.append('File', file);
                form_data.append('CurrentDir', CURRENT_DIR);
                form_data.append('RelativePath', file.filepath);
            }
        });

        try {
            const response = await fetch('/api/upload-file/', {
                method: 'POST',
                body: form_data
            });

            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }

            UpdateFileList(CURRENT_DIR);
            upload_dialog.style.display = 'none';
        } catch (error) {
            alert("上传文件异常: " + error.message);
            upload_dialog.style.display = 'none';
        }
    });
}