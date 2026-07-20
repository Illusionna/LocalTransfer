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
    const rename_dir = CURRENT_DIR;
    const dialog = document.querySelector('.rename-dialog');
    if (selected_files.length === 1) {
        dialog.innerHTML = `
            <div class="rename-dialog-content">
                <p></p>
                <input id="rename-single" style="margin-bottom: 30px;" type="text" placeholder=">>> 新的名字">
                <button class="rename-dialog-cancel">取消</button>
                <button class="rename-dialog-ok">确定</button>
            </div>
        `;
        dialog.style.display = 'block';

        dialog.querySelector('p').textContent = `旧的名字：${selected_files[0].Path}`;
        const ok_button = document.querySelector('.rename-dialog-ok');
        const cancel_button = document.querySelector('.rename-dialog-cancel');
        ok_button.addEventListener('click', async () => {
            if (ok_button.disabled) return;
            const value = document.getElementById('rename-single').value.trim();
            if (value.length === 0) {
                alert('新的名字不能为空.');
                return;
            }
            let result = selected_files.map(item => ({
                OldName: item.Path,
                NewName: value,
                CurrentDir: rename_dir,
                Prefix: "",
                Suffix: ""
            }));
            try {
                ok_button.disabled = true;
                cancel_button.disabled = true;
                const response = await fetch('/api/rename-file/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(result)
                });
                await ReadOperationResults(response);
                await UpdateFileList(CURRENT_DIR);
                dialog.style.display = 'none';
            } catch (error) {
                alert("重命名异常: " + error.message);
            } finally {
                ok_button.disabled = false;
                cancel_button.disabled = false;
            }
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

        const ok_button = document.querySelector('.rename-dialog-ok');
        const cancel_button = document.querySelector('.rename-dialog-cancel');
        ok_button.addEventListener('click', async () => {
            if (ok_button.disabled) return;
            const prefix = document.getElementById('rename-prefix').value;
            const suffix = document.getElementById('rename-suffix').value;
            let result = selected_files.map(item => ({
                OldName: item.Path,
                NewName: "",
                CurrentDir: rename_dir,
                Prefix: prefix,
                Suffix: suffix
            }));
            try {
                ok_button.disabled = true;
                cancel_button.disabled = true;
                const response = await fetch('/api/rename-file/', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(result)
                });
                await ReadOperationResults(response);
                await UpdateFileList(CURRENT_DIR);
                dialog.style.display = 'none';
            } catch (error) {
                alert("重命名异常: " + error.message);
            } finally {
                ok_button.disabled = false;
                cancel_button.disabled = false;
            }
        });
    }

    document.querySelector('.rename-dialog-cancel').addEventListener('click', () => {
        dialog.style.display = 'none';
    });
}
