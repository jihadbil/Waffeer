import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/ai_chat_message.dart';
import '../../../providers/ai_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../widgets/ai_action_card.dart';
import '../settings/ai_settings_screen.dart';

/// شاشة المستشار المالي الشخصي الذكي في وفير
class AiAdvisorScreen extends StatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  State<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends State<AiAdvisorScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showFinancialPill = true;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final ai = context.read<AiProvider>();
    if (ai.isAdvisorThinking) return;

    final text = presetText ?? _inputController.text.trim();
    if (text.isEmpty) return;

    if (presetText == null) {
      _inputController.clear();
    }
    FocusScope.of(context).unfocus();

    _scrollToBottom();
    await ai.sendAdvisorMessage(question: text, context: context);
    _scrollToBottom();
  }

  void _confirmClearChat(BuildContext context, bool isArabic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isArabic ? 'مسح المحادثة؟' : 'Clear chat?'),
        content: Text(
          isArabic
              ? 'هل ترغب في مسح سجل المحادثة والبدء من جديد؟'
              : 'Do you want to clear the conversation history and start fresh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AiProvider>().clearChat();
            },
            child: Text(isArabic ? 'مسح' : 'Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ai = context.watch<AiProvider>();
    final wallets = context.watch<WalletProvider>();
    final tx = context.watch<TransactionProvider>();
    final isArabic = settings.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Colors.blueAccent],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'مستشار وفير الذكي' : 'Waffeer AI Advisor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  isArabic ? 'متصل بنموذج Gemini' : 'Powered by Gemini',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isArabic ? 'مسح المحادثة' : 'Clear chat',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClearChat(context, isArabic),
          ),
          IconButton(
            tooltip: isArabic ? 'إعدادات الذكاء الاصطناعي' : 'AI Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط النظرة المالية السريعة
          if (_showFinancialPill)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.blue.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : Colors.blue.shade100,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insights_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'الرصيد: ${CurrencyFormatter.format(wallets.totalBalance, currencyCode: settings.currencyCode, isArabic: isArabic)} • صرف الشهر: ${CurrencyFormatter.format(tx.monthlyExpense, currencyCode: settings.currencyCode, isArabic: isArabic)}'
                          : 'Balance: ${CurrencyFormatter.format(wallets.totalBalance, currencyCode: settings.currencyCode, isArabic: isArabic)} • Month Expense: ${CurrencyFormatter.format(tx.monthlyExpense, currencyCode: settings.currencyCode, isArabic: isArabic)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showFinancialPill = false),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // قائمة الرسائل
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: ai.chatMessages.length + (ai.isAdvisorThinking ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == ai.chatMessages.length && ai.isAdvisorThinking) {
                  return _buildThinkingBubble(isDark, isArabic);
                }
                final msg = ai.chatMessages[index];
                return _buildMessageBubble(msg, isDark, isArabic);
              },
            ),
          ),

          // الأسئلة السريعة المقترحة
          if (!ai.isAdvisorThinking)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  _buildQuickChip(isArabic ? 'سجل مصروف 45 ريال قهوة كاش' : 'Record 45 SAR coffee expense', isArabic),
                  _buildQuickChip(isArabic ? 'سجل دخل 2500 ريال مكافأة' : 'Record 2500 SAR bonus income', isArabic),
                  _buildQuickChip(isArabic ? 'أضف تصنيف اشتراكات' : 'Add Subscriptions category', isArabic),
                  _buildQuickChip(isArabic ? 'فعل الوضع الداكن' : 'Enable Dark Mode', isArabic),
                  _buildQuickChip(isArabic ? 'ما تقييمك لوضعي المالي؟' : 'Evaluate my finances', isArabic),
                  _buildQuickChip(isArabic ? 'كيف أوفر 10% من دخلي؟' : 'How to save 10%?', isArabic),
                  _buildQuickChip(isArabic ? 'هل أنا ملتزم بميزانياتي؟' : 'Am I on budget?', isArabic),
                ],
              ),
            ),

          // حقل الإدخال السفلي
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: ai.isAdvisorThinking ? null : (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'اسأل مستشارك المالي أي سؤال...'
                            : 'Ask your AI financial advisor...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: ai.isAdvisorThinking ? null : () => _sendMessage(),
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String text, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.only(right: 6, left: 6),
      child: ActionChip(
        label: Text(text, style: const TextStyle(fontSize: 11)),
        avatar: const Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
        onPressed: () => _sendMessage(text),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isDark, bool isArabic) {
    final isUser = msg.isUser;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.primary
                            : (isDark ? AppColors.darkCard : Colors.white),
                        borderRadius: BorderRadius.circular(18).copyWith(
                          bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                          bottomLeft: !isUser ? const Radius.circular(4) : const Radius.circular(18),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                        boxShadow: [
                          if (!isUser)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: SelectableText(
                        msg.content,
                        style: TextStyle(
                          color: isUser ? Colors.white : (isDark ? Colors.white : Colors.black87),
                          fontSize: 14,
                          height: 1.5,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    if (!isUser && msg.actions.isNotEmpty)
                      for (final act in msg.actions)
                        AiActionCard(action: act),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade300,
                  child: const Icon(Icons.person, size: 16, color: Colors.black87),
                ),
              ],
            ],
          ),

          // Follow-up chips if provided
          if (!isUser && msg.suggestedFollowUps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 36, left: 36),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.suggestedFollowUps.map((chipText) {
                  return ActionChip(
                    label: Text(chipText, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _sendMessage(chipText),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble(bool isDark, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  isArabic ? 'المستشار يحلل أرقامك المالية...' : 'Advisor is analyzing your finances...',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
