const announcement_board = document.querySelector('.announcement-board');


document.querySelector('.nav-item img[src="/UI/assets/images/announcement.svg"]').parentElement.addEventListener('click', () => {
    if (announcement_board.style.display === 'block') {
        SendAnnouncement();
        announcement_board.style.display = 'none';
    } else {
        ViewAnnouncement();
    }
});


announcement_board.addEventListener('click', (event) => {
    if (!event.target.closest('#contenteditable')) {
        SendAnnouncement();
        announcement_board.style.display = 'none';
    }
});


async function SendAnnouncement() {
    const content = document.getElementById('contenteditable').innerHTML;
    try {
        const response = await fetch('/api/edit-announcement/', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ Content: content }),
        });
        if (!response.ok) {
            throw new Error(`[* HTTP ${response.status}], 建议刷新重试.`);
        }
    } catch (error) {
        alert("将公告板的内容发送到后端异常: " + error.message);
        return;
    }
}


async function ViewAnnouncement() {
    try {
        return await fetch('/api/announcement-content/', {
            method: 'POST',
            headers: {
                'Accept': 'application/json'
            },
        })
        .then(response => response.json())
        .then(data => {
            announcement_board.innerHTML = `
                <div contenteditable id="contenteditable">${data.Content}</div>
            `;
            announcement_board.style.display = 'block';
        })
    } catch (error) {
        alert("从后端获取公告板内容异常: " + error.message);
        return;
    }
}