const property_dialog = document.querySelector('.property-dialog');


property_dialog.addEventListener('click', () => {
    property_dialog.style.display = 'none';
});


document.querySelector('.nav-item img[src="/UI/assets/images/property.svg"]').parentElement.addEventListener('click', ViewFileProperty);



async function ViewFileProperty() {
    const selected_checkboxs = document.querySelectorAll('.file-item input[type="checkbox"]:checked');
    const selected_files = Array.from(selected_checkboxs).map(c => {
        const file_name = c.parentElement.querySelector('.file-name').textContent;
        return {
            Path: CURRENT_DIR === '.' ? file_name : `${CURRENT_DIR}/${file_name}`
        };
    });
    if (selected_files.length === 0) {
        alert('请勾选查看属性的文件😊');
        return;
    }

    const content = document.querySelector('.property-dialog');
    content.innerHTML = ``;
    property_dialog.style.display = 'block';

    try {
        const response = await fetch('/api/file-property/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(selected_files)
        });
        if (!response.ok) {
            throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
        }
        DisplayFileInfo(await response.json());
    } catch (error) {
        alert("获取文件属性异常: " + error.message);
    }
}


function DisplayFileInfo(FILE_PROPERTY) {
    const content = document.querySelector('.property-dialog');
    content.innerHTML = `
        <p>文件个数：${FILE_PROPERTY.FileCount}</p>
        <p>累计大小：${FILE_PROPERTY.SumSize}</p>
        <p>修改时间：${FILE_PROPERTY.ModifiedTime}<br><span style="margin-left: 5em;">${FILE_PROPERTY.AgoTime}</span></p>
    `;
}