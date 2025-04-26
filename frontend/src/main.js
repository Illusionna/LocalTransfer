import {SynchronizeSettings} from '../wailsjs/go/main/APP';
import {SynchronizeServer} from '../wailsjs/go/main/APP';
import {InitConfig} from '../wailsjs/go/main/APP';


// 语言配置
const translations = {
    zh: {
        serverStopped: "服务器已停止",
        serverRunning: "服务器运行中",
        startServer: "启动服务器",
        stopServer: "停止服务器",
        ipLabel: "IP 地址",
        portLabel: "端口",
        shareFolderLabel: "共享文件夹路径",
        savePathLabel: "保存路径",
        passwordLabel: "登录密码",
        maxSizeLabel: "限制上传文件最大尺寸",
        enableUploadLabel: "上传功能",
        enableDeleteLabel: "删除功能",
        enableRenameLabel: "重命名功能",
        enableSearchLabel: "搜索功能",
        enableBoardLabel: "公告功能",
        enableMkdirLabel: "新建文件夹功能",
        enableCopyLabel: "复制粘贴功能",
        enableMoveLabel: "剪切移动功能",
        saveSettings: "保存设置",
        settingsSaved: "设置已保存",
        serverStarted: "服务器已启动",
        serverStopped: "服务器已停止",
        error: "发生错误",
        serverConfig: "服务器配置",
        functionSettings: "功能设置"
    },
    en: {
        serverStopped: "Server is stopped",
        serverRunning: "Server is running",
        startServer: "Start Server",
        stopServer: "Stop Server",
        ipLabel: "IP Address",
        portLabel: "Port",
        shareFolderLabel: "Share Folder Path",
        savePathLabel: "Save Path",
        maxSizeLabel: "Restrict the Max Size of Uploaded Files",
        passwordLabel: "Login Password",
        enableUploadLabel: "Upload function",
        enableDeleteLabel: "Delete function",
        enableRenameLabel: "Rename function",
        enableSearchLabel: "Search function",
        enableBoardLabel: "Board function",
        enableMkdirLabel: "Make folder function",
        enableCopyLabel: "Copy and paste function",
        enableMoveLabel: "Move and place function",
        saveSettings: "Save Settings",
        settingsSaved: "Settings saved",
        serverStarted: "Server started",
        serverStopped: "Server stopped",
        error: "Error occurred",
        serverConfig: "Server Configuration",
        functionSettings: "Function Settings"
    }
};

// 元素引用
const elements = {
    langToggle: document.getElementById('langToggle'),
    statusText: document.getElementById('statusText'),
    toggleServer: document.getElementById('toggleServer'),
    statusDot: document.getElementById('statusDot'),
    ipLabel: document.getElementById('ipLabel'),
    portLabel: document.getElementById('portLabel'),
    shareFolderLabel: document.getElementById('shareFolderLabel'),
    savePathLabel: document.getElementById('savePathLabel'),
    passwordLabel: document.getElementById('passwordLabel'),
    maxSizeLabel: document.getElementById('maxSizeLabel'),
    enableUploadLabel: document.getElementById('enableUploadLabel'),
    enableDeleteLabel: document.getElementById('enableDeleteLabel'),
    enableRenameLabel: document.getElementById('enableRenameLabel'),
    enableSearchLabel: document.getElementById('enableSearchLabel'),
    enableBoardLabel: document.getElementById('enableBoardLabel'),
    enableMkdirLabel: document.getElementById('enableMkdirLabel'),
    enableCopyLabel: document.getElementById('enableCopyLabel'),
    enableMoveLabel: document.getElementById('enableMoveLabel'),
    saveSettings: document.getElementById('saveSettings'),
    notification: document.getElementById('notification'),
    notificationMessage: document.getElementById('notificationMessage'),
    ipAddress: document.getElementById('ipAddress'),
    port: document.getElementById('port'),
    shareFolder: document.getElementById('shareFolder'),
    savePath: document.getElementById('savePath'),
    password: document.getElementById('password'),
    maxSize: document.getElementById('maxSize'),
    enableUpload: document.getElementById('enableUpload'),
    enableDelete: document.getElementById('enableDelete'),
    enableRename: document.getElementById('enableRename'),
    enableSearch: document.getElementById('enableSearch'),
    enableBoard: document.getElementById('enableBoard'),
    enableMkdir: document.getElementById('enableMkdir'),
    enableCopy: document.getElementById('enableCopy'),
    enableMove: document.getElementById('enableMove'),
    langZh: document.getElementById('langZh'),
    langEn: document.getElementById('langEn'),
    sectionTitles: document.querySelectorAll('.section-title')
};

// 应用当前语言
async function applyLanguage(lang) {
    const text = translations[lang];
    elements.statusText.textContent = isServerRunning ? text.serverRunning : text.serverStopped;
    elements.toggleServer.textContent = isServerRunning ? text.stopServer : text.startServer;
    elements.ipLabel.textContent = text.ipLabel;
    elements.portLabel.textContent = text.portLabel;
    elements.shareFolderLabel.textContent = text.shareFolderLabel;
    elements.savePathLabel.textContent = text.savePathLabel;
    elements.passwordLabel.textContent = text.passwordLabel;
    elements.maxSizeLabel.textContent = text.maxSizeLabel;
    elements.enableUploadLabel.textContent = text.enableUploadLabel;
    elements.enableDeleteLabel.textContent = text.enableDeleteLabel;
    elements.enableRenameLabel.textContent = text.enableRenameLabel;
    elements.enableSearchLabel.textContent = text.enableSearchLabel;
    elements.enableBoardLabel.textContent = text.enableBoardLabel;
    elements.enableMkdirLabel.textContent = text.enableMkdirLabel;
    elements.enableCopyLabel.textContent = text.enableCopyLabel;
    elements.enableMoveLabel.textContent = text.enableMoveLabel;
    elements.saveSettings.textContent = text.saveSettings;
    elements.sectionTitles[0].textContent = text.serverConfig;
    elements.sectionTitles[1].textContent = text.functionSettings;

    const response = await InitConfig();
    elements.ipAddress.value = response['ip'];
    elements.port.value = response['port'];
    elements.shareFolder.value = response['share_dir'];
    elements.savePath.value = response['upload_dir'];
    elements.maxSize.value = response['max_size'];
    elements.password.value = response['password'];
}

// 显示通知
function showNotification(message, type = 'success') {
    elements.notification.className = `notification ${type} show`;
    elements.notificationMessage.textContent = message;
    
    setTimeout(() => {
        elements.notification.classList.remove('show');
    }, 2000);
}

// 服务器状态和控制
let isServerRunning = false;
let currentLanguage = 'zh';

// 切换服务器状态
function toggleServer() {
    isServerRunning = !isServerRunning;

    if (isServerRunning) {
        elements.statusDot.classList.add('active');
        elements.toggleServer.classList.add('running');
        showNotification(translations[currentLanguage].serverStarted);
    } else {
        elements.statusDot.classList.remove('active');
        elements.toggleServer.classList.remove('running');
        showNotification(translations[currentLanguage].serverStopped);
    }
    
    elements.statusText.textContent = isServerRunning 
        ? translations[currentLanguage].serverRunning 
        : translations[currentLanguage].serverStopped;
    
    elements.toggleServer.textContent = isServerRunning 
        ? translations[currentLanguage].stopServer 
        : translations[currentLanguage].startServer;
    
    try {
        SynchronizeServer(isServerRunning);
    } catch (error) {
        console.error(error);
    }
}

// 修改保存设置函数 - 移除延迟
function saveSettings() {
    // 在实际应用中，这里应该发送设置到后端
    const settings = {
        ipAddress: elements.ipAddress.value || '127.0.0.1',
        port: elements.port.value || '8888',
        shareFolder: elements.shareFolder.value || '.',
        savePath: elements.savePath.value || '.',
        password: elements.password.value || '',
        maxSize: elements.maxSize.value || '1.2 GB',
        enableUpload: elements.enableUpload.checked,
        enableDelete: elements.enableDelete.checked,
        enableRename: elements.enableRename.checked,
        enableSearch: elements.enableSearch.checked,
        enableBoard: elements.enableBoard.checked,
        enableMkdir: elements.enableMkdir.checked,
        enableCopy: elements.enableCopy.checked,
        enableMove: elements.enableMove.checked
    };
    
    // 直接显示通知，移除延迟
    showNotification(translations[currentLanguage].settingsSaved);
    
    // 这里可以添加与后端通信的代码
    try {
        SynchronizeSettings(settings);
    } catch (error) {
        console.error(error);
    }
}

// 事件监听器
elements.langToggle.addEventListener('change', function() {
    currentLanguage = this.checked ? 'en' : 'zh';
    applyLanguage(currentLanguage);
});

elements.toggleServer.addEventListener('click', toggleServer);
elements.saveSettings.addEventListener('click', saveSettings);


// 初始设置
applyLanguage(currentLanguage);