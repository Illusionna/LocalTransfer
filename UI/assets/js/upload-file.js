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
            // 显示进度条和文本
            progress_container.style.display = 'block';
            progress_text.style.display = 'block';
        
            // 禁用按钮
            document.querySelector('.upload-dialog-ok').disabled = true;
            document.querySelector('.upload-dialog-cancel').disabled = true;
        
            const xhr = new XMLHttpRequest();
        
            // 进度监听
            xhr.upload.addEventListener('progress', (event) => {
                if (event.lengthComputable) {
                    const percentComplete = Math.round((event.loaded / event.total) * 100);
                    progress_bar.style.width = percentComplete + '%';
                    progress_bar.textContent = percentComplete + '%';
                    progress_text.textContent = `已上传 ${FormatFileSize(event.loaded)} / ${FormatFileSize(event.total)}`;
                }
            });
        
            // 错误处理
            xhr.onerror = function () {
                alert("上传失败：网络错误，请检查网络连接或尝试上传更小的文件。");
                upload_dialog.style.display = 'none';
                document.querySelector('.upload-dialog-ok').disabled = false;
                document.querySelector('.upload-dialog-cancel').disabled = false;
            };

            // 请求完成处理
            xhr.onload = function () {
                if (xhr.status == 200) {
                    UpdateFileList(CURRENT_DIR);
                    progress_text.textContent = '成功';
                    document.querySelector('.upload-dialog-ok').disabled = false;
                    document.querySelector('.upload-dialog-cancel').disabled = false;
                } else if (xhr.status == 413) {
                    alert(`上传失败，文件大小超出服务器预设的最大限制。`);
                    upload_dialog.style.display = 'none';
                } else if (xhr.status == 500) {
                    alert(`上传失败，存在未知且无法解析的文件，建议一部分一部分上传，以找出错误文件。`);
                    upload_dialog.style.display = 'none';
                } else {
                    alert(`上传失败：服务器错误（状态码 ${xhr.status}）`);
                    upload_dialog.style.display = 'none';
                }
            };
        
            // 发送请求
            xhr.open('POST', '/api/upload-file/', true);
            xhr.send(form_data);
        } catch (error) {
            // 捕获同步异常
            alert("上传文件异常：" + error.message);
            upload_dialog.style.display = 'none';
            document.querySelector('.upload-dialog-ok').disabled = false;
            document.querySelector('.upload-dialog-cancel').disabled = false;
        }

    });

    function FormatFileSize(bytes) {
        if (bytes === 0) return '0 Bytes';
        const k = 1024;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
    }
}