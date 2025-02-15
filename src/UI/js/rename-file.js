document.querySelector('.more-item img[src="/UI/assets/images/rename.svg"]').parentElement.addEventListener('click', RenameFile);


function RenameFile() {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {
            Path: file_name
        };
    });
    if (selected_files.length === 0) {
        alert('请勾选需要改名的文件😊');
        return;
    }
    const dialog = document.querySelector('.rename-dialog');
    if (selected_files.length === 1) {
        dialog.innerHTML = `
            <div class="rename-dialog-content">
                <p>旧的名字：${selected_files[0].Path}</p>
                <input id="rename-single" style="margin-bottom: 30px;" type="text" placeholder=">>> 新的名字">
                <button class="rename-dialog-cancel">取消</button>
                <button class="rename-dialog-ok">确定</button>
            </div>
        `;
        dialog.style.display = 'block';

        document.querySelector('.rename-dialog-ok').addEventListener('click', async () => {
            const value = document.getElementById('rename-single').value;
            let result = selected_files.map(item => ({
                OldName: item.Path,
                NewName: value,
                CurrentDir: CURRENT_DIR,
                Prefix: "",
                Suffix: ""
            }));
            try {
                const response = await fetch('/api/rename-file/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(result)
                });
                if (!response.ok) {
                    throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
                }
            } catch (error) {
                alert("重命名异常: " + error.message);
            }
            UpdateFileList(CURRENT_DIR);
            document.querySelector('.rename-dialog').style.display = 'none';
        });

    } else {
        dialog.innerHTML = `
            <div class="rename-dialog-content">
                <input id="rename-prefix" style="margin-bottom: 30px;" type="text" placeholder=">>> 批量前缀（e.g. 图片）">
                <input id="rename-suffix" style="margin-bottom: 30px;" type="text" placeholder=">>> 批量后缀（e.g. 号）">
                <button class="rename-dialog-cancel">取消</button>
                <button class="rename-dialog-ok">确定</button>
            </div>
        `;
        dialog.style.display = 'block';

        document.querySelector('.rename-dialog-ok').addEventListener('click', async () => {
            const prefix = document.getElementById('rename-prefix').value;
            const suffix = document.getElementById('rename-suffix').value;
            let result = selected_files.map(item => ({
                OldName: item.Path,
                NewName: "",
                CurrentDir: CURRENT_DIR,
                Prefix: prefix,
                Suffix: suffix
            }));
            try {
                const response = await fetch('/api/rename-file/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(result)
                });
                if (!response.ok) {
                    throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
                }
            } catch (error) {
                alert("重命名异常: " + error.message);
            }
            UpdateFileList(CURRENT_DIR);
            document.querySelector('.rename-dialog').style.display = 'none';
        });
    }

    document.querySelector('.rename-dialog-cancel').addEventListener('click', () => {
        dialog.style.display = 'none';
    });
}