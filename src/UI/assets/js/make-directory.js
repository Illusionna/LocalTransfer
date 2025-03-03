document.querySelector('.more-item img[src="/UI/assets/images/create.svg"]').parentElement.addEventListener('click', MakedirDialog);


function MakedirDialog() {
    const dialog = document.querySelector('.makedir-dialog');
    dialog.innerHTML = `
        <div class="makedir-dialog-content">
            <div><input id="makedir" style="margin-bottom: 30px;" type="text" placeholder=">>> 新建文件夹名称"></div>
            <button class="makedir-dialog-cancel">取消</button>
            <button class="makedir-dialog-ok">确定</button>
        </div>
    `
    dialog.style.display = 'block';

    document.querySelector('.makedir-dialog-cancel').addEventListener('click', () => {
        dialog.style.display = 'none';
    });

    document.querySelector('.makedir-dialog-ok').addEventListener('click', async () => {
        try {
            const value = document.getElementById('makedir').value;
            const response = await fetch('/api/make-directory/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({"Path": value, "CurrentDir": CURRENT_DIR})
            });
            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }
            UpdateFileList(CURRENT_DIR);
            dialog.style.display = 'none';
        } catch (error) {
            alert("创建文件夹异常: " + error.message);
            dialog.style.display = 'none';
            return;
        }
    });
}