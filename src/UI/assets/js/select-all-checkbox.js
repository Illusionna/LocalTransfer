function RefreshSelectAllCheckboxStatus() {
    const select_all_checkbox_btn = document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]')?.parentElement;
    if (!select_all_checkbox_btn) return;
    const checkboxes = Array.from(document.querySelectorAll('.file-item input[type="checkbox"]'));
    const is_all_selected = checkboxes.length > 0 && checkboxes.every(c => c.checked);
    select_all_checkbox_btn.querySelector('span').textContent = is_all_selected ? '取消' : '全选';
}


function BindSelectAllCheckboxEvent() {
    const select_all_checkbox_btn = document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement;

    function GetCheckboxes() {
        return Array.from(document.querySelectorAll('.file-item input[type="checkbox"]'));
    }

    select_all_checkbox_btn.addEventListener('click', () => {
        const checkboxes = GetCheckboxes();
        if (checkboxes.length === 0) {
            RefreshSelectAllCheckboxStatus();
            return;
        }
        const is_all_selected = checkboxes.every(c => c.checked);
        checkboxes.forEach(c => {
            c.checked = !is_all_selected;
            c.dispatchEvent(new Event('change', { bubbles: true }));
        });
        RefreshSelectAllCheckboxStatus();
    });

    document.querySelector('.file-content').addEventListener('change', (e) => {
        if (e.target.matches('.file-item input[type="checkbox"]')) {
            RefreshSelectAllCheckboxStatus();
        }
    });

    RefreshSelectAllCheckboxStatus();
}


document.addEventListener('DOMContentLoaded', () => {
    BindSelectAllCheckboxEvent();
});
