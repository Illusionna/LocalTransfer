let COPY_PASTE_LOCK = false;
let COPY_PASTE_SELECTED_FILES = [];
let COPY_PASTE_BUSY = false;


document.getElementById('paste').parentElement.addEventListener('click', async () => {
    if (COPY_PASTE_BUSY) return;
    if (COPY_PASTE_LOCK) {
        COPY_PASTE_BUSY = true;
        try {
            await PasteSelectedFile();
        } finally {
            COPY_PASTE_BUSY = false;
        }
    } else {
        CopySelectedFile();
    }
});


document.addEventListener('change', function(e) {
    if (e.target.matches('.file-item input[type="checkbox"]')) {
        ChangeCopyPasteLockStatus();
    }
});


function CopySelectedFile() {
    if (!COPY_PASTE_LOCK) {
        const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
        COPY_PASTE_SELECTED_FILES = Array.from(selected_checkboxs).map(c => {
            const file_name = c.parentElement.querySelector('.file-name').textContent;
            return {
                Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`
            };
        });

        if (COPY_PASTE_SELECTED_FILES.length === 0) {
            alert('请选中需要复制的文件😊');
            return;
        }

        selected_checkboxs.forEach(c => {
            c.checked = false;
            c.dispatchEvent(new Event('change', { bubbles: true }));
        });

        document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement.querySelector('span').textContent = '全选';
        document.getElementById('paste').parentElement.querySelector('span').textContent = '粘贴';
        document.getElementById('paste').parentElement.querySelector('img').src = '/UI/assets/images/paste.svg';

        COPY_PASTE_LOCK = true;
    }
}


async function PasteSelectedFile() {
    if (COPY_PASTE_SELECTED_FILES.length != 0) {
        const result = COPY_PASTE_SELECTED_FILES.map(file => {
            return {...file, CurrentDir: CURRENT_DIR};
        });
        try {
            const response = await fetch('/api/copy-file/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(result)
            });
            await ReadOperationResults(response);
        } catch (error) {
            alert("粘贴文件异常: " + error.message);
        }
        try {
            await UpdateFileList(CURRENT_DIR);
        } catch (error) {
            alert("刷新文件列表异常: " + error.message);
        }
        ResetCopyPasteStatus();
    }
}


function ChangeCopyPasteLockStatus() {
    if (COPY_PASTE_LOCK) {
        const any_selected_checkbox = Array.from(document.querySelectorAll('.file-item input[type="checkbox"]')).some(c => c.checked);
        if (any_selected_checkbox) {
            // 如果有任意一个复选框被选中, 则清空列表, 然后关闭锁, 切换成粘贴的图标.
            ResetCopyPasteStatus();
        }
    }
}


function ResetCopyPasteStatus() {
    document.getElementById('paste').parentElement.querySelector('span').textContent = '复制';
    document.getElementById('paste').parentElement.querySelector('img').src = '/UI/assets/images/copy.svg';
    COPY_PASTE_SELECTED_FILES = [];
    COPY_PASTE_LOCK = false;
}
