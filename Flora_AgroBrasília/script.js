document.addEventListener('DOMContentLoaded', () => {
    const input = document.querySelector('.input-container input');
    const sendBtn = document.querySelector('.btn-send');
    const chatContent = document.querySelector('.chat-content');

    function sendMessage() {
        const text = input.value.trim();
        if (text === '') return;

        // Add user message
        const userMsg = document.createElement('div');
        userMsg.className = 'message user-message';
        userMsg.innerHTML = `
            <div class="message-text">
                <p>${text}</p>
            </div>
        `;
        chatContent.appendChild(userMsg);

        // Clear input
        input.value = '';

        // Scroll to bottom
        chatContent.scrollTop = chatContent.scrollHeight;

        // Simple bot reaction
        setTimeout(() => {
            const botMsg = document.createElement('div');
            botMsg.className = 'message flora-message';
            botMsg.innerHTML = `
                <div class="message-text">
                    <p>Entendi! Estou processando sua pergunta sobre "<strong>${text}</strong>". Em instantes trarei as melhores recomendações técnicas da Embrapa para você.</p>
                </div>
            `;
            chatContent.appendChild(botMsg);
            chatContent.scrollTop = chatContent.scrollHeight;
        }, 1000);
    }

    sendBtn.addEventListener('click', sendMessage);
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') sendMessage();
    });
});
