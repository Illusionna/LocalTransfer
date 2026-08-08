const delete_dialog = document.querySelector('.delete-dialog');
let pending_delete_files = [];
let delete_in_progress = false;


document.querySelector('.nav-item img[src="/UI/assets/images/delete.svg"]').parentElement.addEventListener('click', CreateDeleteDialog);


async function DeleteSelectedFile() {
    if (delete_in_progress) {
        return;
    }
    if (pending_delete_files.length === 0) {
        alert('请勾选需要删除的文件😊');
        return;
    }

    delete_in_progress = true;
    const selected_files = pending_delete_files.slice();
    const ok_button = delete_dialog.querySelector('.delete-dialog-ok');
    const cancel_button = delete_dialog.querySelector('.delete-dialog-cancel');
    if (ok_button) ok_button.disabled = true;
    if (cancel_button) cancel_button.disabled = true;

    try {
        const response = await fetch('/api/delete-file/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selected_files)
        });
        await ReadOperationResults(response);
        selected_files.forEach(file => SELECTED_FILE_PATHS.delete(file.Path));
        pending_delete_files = [];
        delete_dialog.style.display = 'none';
        try {
            await UpdateFileList(CURRENT_DIR);
        } catch (error) {
            console.error('删除成功，但刷新文件列表失败:', error);
        }
    } catch (error) {
        alert("删除文件异常: " + error.message);
    } finally {
        delete_in_progress = false;
        if (ok_button && ok_button.isConnected) ok_button.disabled = false;
        if (cancel_button && cancel_button.isConnected) cancel_button.disabled = false;
    }
}


function CreateDeleteDialog() {
    if (delete_in_progress) {
        return;
    }
    SyncVisibleSelections();
    pending_delete_files = Array.from(SELECTED_FILE_PATHS, path => ({Path: path}));

    if (pending_delete_files.length === 0) {
        alert('请勾选需要删除的文件😊');
        return;
    }

    delete_dialog.style.display = 'block';

    const content = document.querySelector('.delete-dialog');
    content.innerHTML = `
        <div class="delete-dialog-content">
            <h3>确定删除么？无法恢复的哦~</h3>
            <button class="delete-dialog-cancel">取消</button>
            <button class="delete-dialog-ok">确定</button>
        </div>
    `;

    document.querySelector('.delete-dialog-cancel').addEventListener('click', () => {
        pending_delete_files = [];
        delete_dialog.style.display = 'none';
    });

    document.querySelector('.delete-dialog-ok').addEventListener('click', DeleteSelectedFile);
}
