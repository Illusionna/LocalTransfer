const delete_dialog = document.querySelector('.delete-dialog');


document.querySelector('.nav-item img[src="/UI/assets/images/delete.svg"]').parentElement.addEventListener('click', CreateDeleteDialog);


async function DeleteSelectedFile() {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`};
    });

    if (selected_files.length === 0) {
        alert('请勾选需要删除的文件😊');
        return;
    }

    try {
        const response = await fetch('/api/delete-file/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selected_files)
        });
        await ReadOperationResults(response);
        delete_dialog.style.display = 'none';
        UpdateFileList(CURRENT_DIR);
    } catch (error) {
        alert("删除文件异常: " + error.message);
        delete_dialog.style.display = 'none';
        return;
    }
}


function CreateDeleteDialog() {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`};
    });

    if (selected_files.length === 0) {
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
        delete_dialog.style.display = 'none';
    });

    document.querySelector('.delete-dialog-ok').addEventListener('click', DeleteSelectedFile);
}
