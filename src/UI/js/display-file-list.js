let CURRENT_DIR = '.';


async function UpdateFileList(path) {
    const response = await fetch(`/api/file-list/?path=${encodeURIComponent(path)}`);
    const data = await response.json();
    const content = document.querySelector('.file-content');
    content.innerHTML = '';
    // 使用 Promise.all 等待所有文件项创建完成.
    const file_items = await Promise.all(data.map(FILE_INFO => CreateFileItem(FILE_INFO)));
    file_items.forEach(item => content.appendChild(item));
    SynchronizeCurrentDirectory(path);
}


async function GetFileIcon(file_icon) {
    const known_icons = ['7z', 'apk', 'avi', 'BACK', 'bat', 'bin', 'bmp', 'c', 'cfg', 'config', 'cpp', 'css', 'csv', 'dat', 'db', 'dll', 'doc', 'docx', 'exe', 'FOLDER', 'gif', 'gitignore', 'go', 'gz', 'html', 'ico', 'ini', 'iso', 'java', 'jpeg', 'jpg', 'js', 'json', 'lnk', 'log', 'm', 'manifest', 'md', 'mlx', 'mov', 'mp3', 'mp4', 'NULL', 'otf', 'pak', 'pdf', 'pkg', 'png', 'ppt', 'pptx', 'psd', 'py', 'rar', 'sh', 'svg', 'tar', 'tex', 'ts', 'ttc', 'ttf', 'txt', 'wav', 'webm', 'webp', 'woff', 'woff2', 'xls', 'xlsx', 'xml', 'xz', 'yaml', 'yml', 'zip'];
    if (known_icons.includes(file_icon)) {
        return `/UI/assets/icons/${file_icon}.svg`;
    }
    return "/UI/assets/icons/NULL.svg";
}


async function CreateFileItem(FILE_INFO) {
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
        checkbox.onclick = (e) => {
            e.stopPropagation();
        };
    }
    div.onclick = () => {
        if (FILE_INFO.FileIcon === 'FOLDER' || FILE_INFO.FileName === '. .') {
            if (FILE_INFO.FileName === '. .') {
                CURRENT_DIR = CURRENT_DIR.split('/').slice(0, -1).join('/') || '.';
            } else {
                CURRENT_DIR = CURRENT_DIR === '.' ? FILE_INFO.FileName : `${CURRENT_DIR}/${FILE_INFO.FileName}`;
            }
            UpdateFileList(CURRENT_DIR);
        } else {
            const file_path = CURRENT_DIR === '.' ? `/api/share/${FILE_INFO.FileName}` : `/api/share/${CURRENT_DIR}/${FILE_INFO.FileName}`;
            const a = document.createElement('a');
            a.href = file_path;
            a.target = '_blank';
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