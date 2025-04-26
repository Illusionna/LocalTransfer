document.querySelector('.more-item img[src="/UI/assets/images/download.svg"]').parentElement.addEventListener('click', BatchDownload);


async function BatchDownload() {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {
            Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`,
            CurrentDir: CURRENT_DIR
        };
    });

    if (selected_files.length === 0) {
        alert('请勾选需要下载的文件😊');
        return;
    }

    try {
        const response = await fetch('/api/batch-download/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selected_files)
        });
        if (!response.ok) {
            throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
        }

        const blob = await response.blob();

        const a = document.createElement('a');
        a.download = 'archive.zip';
        a.href = window.URL.createObjectURL(blob);
        a.click();
        URL.revokeObjectURL(a.href);
        a.remove();
    } catch (error) {
        alert("下载文件异常: " + error.message);
        return;
    }
}