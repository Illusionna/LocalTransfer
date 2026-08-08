let CURRENT_DIR = '.';
let RENDERED_DIR = '.';
let FILE_LIST_UPDATE_ID = 0;
const SELECTED_FILE_PATHS = new Set();


function BuildFilePath(path, file_name) {
    return path === '.' ? file_name : `${path}/${file_name}`;
}


async function ReadOperationResults(response) {
    const results = await response.json().catch(() => []);
    const failures = Array.isArray(results) ? results.filter(result => !result.Success) : [];
    if (!response.ok || failures.length > 0) {
        const details = failures.map(result => `${result.Path}: ${result.Error}`).join('\n');
        throw new Error(details || `[* HTTP ${response.status}], 建议刷新重试.`);
    }
    return results;
}


function SyncVisibleSelections() {
    document.querySelectorAll('.file-item input[type="checkbox"]').forEach(checkbox => {
        if (!checkbox.dataset.path) {
            return;
        }
        if (checkbox.checked) {
            SELECTED_FILE_PATHS.add(checkbox.dataset.path);
        } else {
            SELECTED_FILE_PATHS.delete(checkbox.dataset.path);
        }
    });
}


function ClearFileSelections() {
    SELECTED_FILE_PATHS.clear();
    document.querySelectorAll('.file-item input[type="checkbox"]').forEach(checkbox => {
        checkbox.checked = false;
    });
    if (typeof RefreshSelectAllCheckboxStatus === 'function') {
        RefreshSelectAllCheckboxStatus();
    }
}


async function UpdateFileList(path) {
    const update_id = ++FILE_LIST_UPDATE_ID;
    const response = await fetch(`/api/file-list/?path=${encodeURIComponent(path)}`);
    const data = await response.json();
    if (update_id !== FILE_LIST_UPDATE_ID) {
        return;
    }
    const content = document.querySelector('.file-content');
    if (path === RENDERED_DIR) {
        SyncVisibleSelections();
    } else {
        SELECTED_FILE_PATHS.clear();
    }
    content.innerHTML = '';
    // 使用 Promise.all 等待所有文件项创建完成.
    const file_items = await Promise.all(data.map(FILE_INFO => CreateFileItem(FILE_INFO, path)));
    if (update_id !== FILE_LIST_UPDATE_ID) {
        return;
    }
    file_items.forEach(item => content.appendChild(item));
    RENDERED_DIR = path;
    SynchronizeCurrentDirectory(path);
    if (typeof RefreshSelectAllCheckboxStatus === 'function') {
        RefreshSelectAllCheckboxStatus();
    }
}


async function GetFileIcon(file_icon) {
    const known_icons = ['7z', 'apk', 'avi', 'BACK', 'bat', 'bin', 'bmp', 'c', 'cfg', 'config', 'cpp', 'css', 'csv', 'dat', 'db', 'dll', 'doc', 'docx', 'exe', 'FOLDER', 'gif', 'gitignore', 'go', 'gz', 'html', 'ico', 'ini', 'iso', 'java', 'jpeg', 'jpg', 'js', 'json', 'lnk', 'log', 'm', 'manifest', 'md', 'mlx', 'mov', 'mp3', 'mp4', 'NULL', 'otf', 'pak', 'pdf', 'pkg', 'png', 'ppt', 'pptx', 'psd', 'py', 'rar', 'sh', 'svg', 'tar', 'tex', 'ts', 'ttc', 'ttf', 'txt', 'wav', 'webm', 'webp', 'woff', 'woff2', 'xls', 'xlsx', 'xml', 'xz', 'yaml', 'yml', 'zip', 'zig'];
    if (known_icons.includes(file_icon)) {
        return `/UI/assets/icons/${file_icon}.svg`;
    }
    return "/UI/assets/icons/NULL.svg";
}


function BuildShareUrl(path, file_name) {
    const full_path = path === '.' ? file_name : `${path}/${file_name}`;
    return `/api/share/${full_path.split('/').map(encodeURIComponent).join('/')}`;
}


async function CreateFileItem(FILE_INFO, path) {
    const div = document.createElement('div');
    div.className = 'file-item';
    div.style.cursor = 'pointer';

    if (FILE_INFO.FileName === '. .') {
        div.innerHTML = `
            <div style="width: 35px;"></div>
            <div class="file-icon">
                <img src="/UI/assets/icons/BACK.svg" draggable="false">
            </div>
            <div class="file-name">${FILE_INFO.FileName}</div>
        `;
    } else {
        const icon_src = await GetFileIcon(FILE_INFO.FileIcon);
        div.innerHTML = `
            <input type="checkbox">
            <div class="file-icon">
                <img src="${icon_src}" draggable="false">
            </div>
            <div class="file-name">${FILE_INFO.FileName}</div>
            <div class="file-size">${FILE_INFO.FileSize}</div>
        `;
    }

    const checkbox = div.querySelector('input[type="checkbox"]');
    if (checkbox) {
        checkbox.dataset.path = BuildFilePath(path, FILE_INFO.FileName);
        checkbox.checked = SELECTED_FILE_PATHS.has(checkbox.dataset.path);
        checkbox.addEventListener('change', () => {
            if (checkbox.checked) {
                SELECTED_FILE_PATHS.add(checkbox.dataset.path);
            } else {
                SELECTED_FILE_PATHS.delete(checkbox.dataset.path);
            }
        });
        checkbox.onclick = (e) => {
            e.stopPropagation();
        };
    }
    div.onclick = (e) => {
        if (e.target.closest('input[type="checkbox"]')) {
            return;
        }
        if (FILE_INFO.FileIcon === 'FOLDER' || FILE_INFO.FileName === '. .') {
            if (FILE_INFO.FileName === '. .') {
                CURRENT_DIR = CURRENT_DIR.split('/').slice(0, -1).join('/') || '.';
            } else {
                CURRENT_DIR = CURRENT_DIR === '.' ? FILE_INFO.FileName : `${CURRENT_DIR}/${FILE_INFO.FileName}`;
            }
            UpdateFileList(CURRENT_DIR);
        } else {
            const a = document.createElement('a');
            a.href = BuildShareUrl(CURRENT_DIR, FILE_INFO.FileName);
            a.target = '_blank';
            a.rel = 'noopener';
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
        }
    }
    return div;
}


function SynchronizeCurrentDirectory(path) {
    const directory = document.querySelector('.current-directory');
    directory.innerHTML = '';
    const span = document.createElement('span');
    span.textContent = '~';
    span.className = 'current-directory-segment';
    span.onclick = () => {
        CURRENT_DIR = '.';
        UpdateFileList(CURRENT_DIR);
    };
    directory.appendChild(span);

    if (path !== '.') {
        const segments = path.split('/');
        let current_segment_path = '';
        segments.forEach((segment, index) => {
            // 添加分隔符.
            const separator = document.createElement('span');
            separator.textContent = ' / ';
            directory.appendChild(separator);
            // 添加路径段落.
            const segment_link = document.createElement('span');
            segment_link.textContent = segment;
            segment_link.className = 'current-directory-segment';
            current_segment_path = index === 0 ? segment : `${current_segment_path}/${segment}`;
            // 创建闭包的副本.
            const path_for_click = current_segment_path;
            segment_link.onclick = () => {
                CURRENT_DIR = path_for_click;
                UpdateFileList(CURRENT_DIR);
            };
            directory.appendChild(segment_link);
        });
    }
}


UpdateFileList(CURRENT_DIR);
