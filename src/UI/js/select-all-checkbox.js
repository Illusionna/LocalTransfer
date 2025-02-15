function BindSelectAllCheckboxEvent() {
    const select_all_checkbox_btn = document.querySelector('.nav-item img[src="/UI/assets/images/select.svg"]').parentElement;
    const select_all_checkbox_text = select_all_checkbox_btn.querySelector('span');
    const checkboxes = document.querySelectorAll('.file-item input[type="checkbox"]');

    function UpdateNavigationSelectButtonText(is_all_selected) {
        select_all_checkbox_text.textContent = is_all_selected ? '取消' : '全选';
    }

    function IsAllSelected() {
        const is_all_selected = Array.from(checkboxes).every(c => c.checked);
        UpdateNavigationSelectButtonText(is_all_selected);
    }

    select_all_checkbox_btn.addEventListener('click', () => {
        const is_all_selected = Array.from(checkboxes).every(c => c.checked);
        checkboxes.forEach(c => {
            c.checked = !is_all_selected;
        });
        UpdateNavigationSelectButtonText(!is_all_selected);
    });

    checkboxes.forEach(c => {
        c.addEventListener('change', IsAllSelected);
    });

    IsAllSelected();
}


document.addEventListener('DOMContentLoaded', () => {
    BindSelectAllCheckboxEvent();
    const file_content = document.querySelector('.file-content');
    const observer = new MutationObserver(() => {
        BindSelectAllCheckboxEvent();
    });
    observer.observe(file_content, {
        childList: true,
        subtree: true
    });
});