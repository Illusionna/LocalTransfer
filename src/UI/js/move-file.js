/* 这是我写的所有 JavaScript 文件里最屎山的代码, 呃呃呃呃, 不过经过我测试, 功能是没有问题的. */

let MOVE_PLACE_LOCK = false;
let MOVE_PLACE_SELECTED_FILES = [];


document.querySelector('.more-item img[src="/UI/assets/images/move.svg"]').parentElement.addEventListener('click', MoveSelectedFile);


document.getElementById('place').parentElement.addEventListener('click', PlaceSelectedFile);


document.addEventListener('change', function(e) {
    if (e.target.matches('.file-item input[type="checkbox"]')) {
        ChangeMovePlaceLockStatus();
    }
});


document.getElementById('place').addEventListener('click', async () => {
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
            if (!response.ok) {
                throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
            }
            UpdateFileList(CURRENT_DIR);
        } catch (error) {
            alert("移动文件异常: " + error.message);
        }
        document.getElementById('place').parentElement.querySelector('span').textContent = '移动';
        document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/move.svg';
        MOVE_PLACE_SELECTED_FILES = [];
        MOVE_PLACE_LOCK = false;
    }
})


async function ChangeMovePlaceLockStatus() {
    if (MOVE_PLACE_LOCK) {
        const any_selected_checkbox = Array.from(document.querySelectorAll('.file-item input[type="checkbox"]')).some(c => c.checked);
        if (any_selected_checkbox) {
            document.getElementById('place').parentElement.querySelector('span').textContent = '移动';
            document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/move.svg';
            // 如果有任意一个复选框被选中, 则清空列表, 然后关闭锁, 切换成移动的图标.
            MOVE_PLACE_SELECTED_FILES = [];
            MOVE_PLACE_LOCK = false;
        }

        document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement.addEventListener('click', () => {
            document.getElementById('place').parentElement.querySelector('span').textContent = '移动';
            document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/move.svg';

            const checkboxes = document.querySelectorAll('.file-item input[type="checkbox"]');
            const is_all_selected = Array.from(checkboxes).every(c => c.checked);
            document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement.querySelector('span').textContent = is_all_selected ? '取消' : '全选';

            MOVE_PLACE_SELECTED_FILES = [];
            MOVE_PLACE_LOCK = false;
        });
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
        });

        document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement.querySelector('span').textContent = '全选';
        document.getElementById('place').parentElement.querySelector('span').textContent = '放置';
        document.getElementById('place').parentElement.querySelector('img').src = '/UI/assets/images/place.svg';

        MOVE_PLACE_LOCK = true;
    }
}


async function PlaceSelectedFile() {
    if (MOVE_PLACE_LOCK) {
        ChangeMovePlaceLockStatus();
    }
}