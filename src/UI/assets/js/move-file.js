/* 这是我写的所有 JavaScript 文件里最屎山的代码, 呃呃呃呃, 不过经过我测试, 功能是没有问题的. */

let MOVE_PLACE_LOCK = false;
let MOVE_PLACE_SELECTED_FILES = [];
let MOVE_PLACE_BUSY = false;


document.getElementById('place').parentElement.addEventListener('click', async () => {
    if (MOVE_PLACE_BUSY) return;
    if (MOVE_PLACE_LOCK) {
        MOVE_PLACE_BUSY = true;
        try {
            await PlaceSelectedFile();
        } finally {
            MOVE_PLACE_BUSY = false;
        }
    } else {
        MoveSelectedFile();
    }
});


document.addEventListener('change', function(e) {
    if (e.target.matches('.file-item input[type="checkbox"]')) {
        ChangeMovePlaceLockStatus();
    }
});


async function ChangeMovePlaceLockStatus() {
    if (MOVE_PLACE_LOCK) {
        const any_selected_checkbox = Array.from(document.querySelectorAll('.file-item input[type="checkbox"]')).some(c => c.checked);
        if (any_selected_checkbox) {
            // 如果有任意一个复选框被选中, 则清空列表, 然后关闭锁, 切换成移动的图标.
            ResetMovePlaceStatus();
        }
    }
}


async function MoveSelectedFile() {
    if (!MOVE_PLACE_LOCK) {
        const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
        MOVE_PLACE_SELECTED_FILES = Array.from(selected_checkboxs).map(c => {
            const file_name = c.parentElement.querySelector('.file-name').textContent;
            return {
                Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`
            };
        });

        if (MOVE_PLACE_SELECTED_FILES.length === 0) {
            alert('请选择需要移动的文件😊');
            return;
        }

        selected_checkboxs.forEach(c => {
            c.checked = false;
            c.dispatchEvent(new Event('change', { bubbles: true }));
        });

        document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement.querySelector('span').textContent = '全选';
        document.getElementById('place').parentElement.querySelector('span').textContent = '放置';
        document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/place.svg';

        MOVE_PLACE_LOCK = true;
    }
}


async function PlaceSelectedFile() {
    if (MOVE_PLACE_SELECTED_FILES.length != 0) {
        const result = MOVE_PLACE_SELECTED_FILES.map(file => {
            return {...file, CurrentDir: CURRENT_DIR};
        });
        try {
            const response = await fetch('/api/move-file/', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(result)
            });
            await ReadOperationResults(response);
        } catch (error) {
            alert("移动文件异常: " + error.message);
        }
        try {
            await UpdateFileList(CURRENT_DIR);
        } catch (error) {
            alert("刷新文件列表异常: " + error.message);
        }
        ResetMovePlaceStatus();
    }
}


function ResetMovePlaceStatus() {
    document.getElementById('place').parentElement.querySelector('span').textContent = '移动';
    document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/move.svg';
    MOVE_PLACE_SELECTED_FILES = [];
    MOVE_PLACE_LOCK = false;
}
