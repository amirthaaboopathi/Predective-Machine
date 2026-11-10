import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/appliance_model.dart';
import '../../models/chat_message_model.dart';
import '../../services/gemini_chat_service.dart';
import '../../services/appliance_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_text_styles.dart';
import '../../widgets/chat_markdown_view.dart';

/// Screen providing interactive AI Chatbot interface for appliance troubleshooting,
/// telemetry queries, health checkups, and smart maintenance recommendations.
class ChatbotScreen extends StatefulWidget {
  final ApplianceModel? initialAppliance;

  const ChatbotScreen({
    super.key,
    this.initialAppliance,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final _chatService = GeminiChatService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    if (widget.initialAppliance != null) {
      _chatService.setScopedAppliance(widget.initialAppliance);
    }

    _chatService.addListener(_handleServiceUpdate);
  }

  @override
  void dispose() {
    _chatService.removeListener(_handleServiceUpdate);
    _pulseController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleServiceUpdate() {
    if (mounted) {
      _scrollToBottom();
    }
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

  Future<void> _sendMessage([String? textOverride]) async {
    final text = textOverride ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (textOverride == null) {
      _textController.clear();
    }

    await _chatService.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _confirmClearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Clear Conversation?'),
          content: const Text(
            'This will clear your current conversation history with the AI Assistant.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      _chatService.clearChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final applianceService = ApplianceService();

    return ListenableBuilder(
      listenable: Listenable.merge([_chatService, applianceService]),
      builder: (context, _) {
        final messages = _chatService.messages;
        final appliances = applianceService.appliances;
        final scoped = _chatService.scopedAppliance;
        final isLoading = _chatService.isLoading;
        final suggestions = _chatService.getSuggestedQuestions();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(scoped),
          body: SafeArea(
            child: Column(
              children: [
                // Appliance Context Scope Selector Bar
                if (appliances.isNotEmpty) _buildApplianceScopeBar(appliances, scoped),

                // Chat Messages List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return _buildThinkingBubble();
                      }
                      final message = messages[index];
                      return _buildMessageItem(message);
                    },
                  ),
                ),

                // Contextual Suggestions Chips Bar (when not loading)
                if (!isLoading && suggestions.isNotEmpty)
                  _buildSuggestionsCarousel(suggestions),

                // Input Bar
                _buildInputBar(isLoading),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ApplianceModel? scoped) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF246BFD), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF246BFD).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Appliance AI',
                  style: AppTextStyles.heading3.copyWith(fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      scoped != null
                          ? 'Focus: ${scoped.name}'
                          : 'Online • Gemini 3.8 Flash',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Clear Conversation',
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.secondaryText),
          onPressed: _confirmClearChat,
        ),
      ],
    );
  }

  Widget _buildApplianceScopeBar(
    List<ApplianceModel> appliances,
    ApplianceModel? scoped,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 14,
                color: AppColors.secondaryText,
              ),
              const SizedBox(width: 6),
              Text(
                'Focus Query Context:',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // "All Appliances" Chip
                ChoiceChip(
                  label: const Text('All Appliances'),
                  selected: scoped == null,
                  onSelected: (selected) {
                    if (selected) {
                      _chatService.setScopedAppliance(null);
                    }
                  },
                  selectedColor: AppColors.primaryBlueLight,
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: scoped == null ? FontWeight.bold : FontWeight.w500,
                    color: scoped == null ? AppColors.primaryBlue : AppColors.darkText,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: scoped == null
                          ? AppColors.primaryBlue
                          : AppColors.borderColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Registered Appliance Chips
                ...appliances.map((app) {
                  final isSelected = scoped?.id == app.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(
                        _getApplianceIcon(app.type),
                        size: 16,
                        color: isSelected ? AppColors.primaryBlue : AppColors.secondaryText,
                      ),
                      label: Text(app.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        _chatService.setScopedAppliance(selected ? app : null);
                      },
                      selectedColor: AppColors.primaryBlueLight,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primaryBlue : AppColors.darkText,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.borderColor,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.status == ChatMessageStatus.error) {
      return _buildErrorBubble(message);
    }
    return message.isUser
        ? _buildUserBubble(message)
        : _buildAssistantBubble(message);
  }

  Widget _buildUserBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 48),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.referencedApplianceName != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Re: ${message.referencedApplianceName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    message.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF246BFD), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: AppColors.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatMarkdownView(text: message.text),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: AppColors.dividerColor),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: AppColors.mutedText,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Response copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                size: 13,
                                color: AppColors.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Copy',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF246BFD), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _pulseController,
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Analyzing appliance telemetry...',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Response Error',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _chatService.retryLastMessage(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsCarousel(List<String> suggestions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: suggestions.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 14,
                  color: AppColors.primaryBlue,
                ),
                label: Text(prompt),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.borderColor),
                ),
                onPressed: () => _sendMessage(prompt),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isLoading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderColor, width: 1),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: AppTextStyles.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Ask about your appliances, issues, or tips...',
                  hintStyle: TextStyle(
                    color: AppColors.mutedText,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) {
                  if (!isLoading) _sendMessage();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isLoading ? AppColors.mutedText : AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
              onPressed: isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getApplianceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'refrigerator':
        return Icons.kitchen_outlined;
      case 'washing machine':
        return Icons.local_laundry_service_outlined;
      case 'air conditioner':
        return Icons.ac_unit_outlined;
      case 'television':
        return Icons.tv_outlined;
      case 'fan':
        return Icons.air_outlined;
      case 'microwave':
        return Icons.microwave_outlined;
      default:
        return Icons.devices_outlined;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
