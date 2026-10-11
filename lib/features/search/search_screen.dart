import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_theme.dart';
import '../../core/services/localization_service.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/moderation_service.dart';
import '../../core/widgets/moderation_actions.dart';
import '../../core/widgets/item_thumbnail_widget.dart';
import '../../core/utils/theme_extensions.dart';
import '../home/home_feed_screen.dart';

class SearchScreen extends StatefulWidget {
  /// When true, hosted inside [MainNavigationScreen] — no back button,
  /// and item taps report via [onItemSelected] instead of replacing the route.
  final bool embeddedInShell;
  final ValueChanged<String>? onItemSelected;

  const SearchScreen({
    super.key,
    this.embeddedInShell = false,
    this.onItemSelected,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    BlockedSellers.instance.addListener(_hideBlockedResults);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
      BlockedSellers.instance.sync();
    });
  }

  bool _isBlockedResult(dynamic item) {
    if (item is! Map) return false;
    final seller = item['seller'];
    if (seller is! Map) return false;
    return BlockedSellers.instance.containsSeller(
      seller['id']?.toString() ?? '',
      seller['uid']?.toString() ?? '',
      seller['name']?.toString() ?? '',
    );
  }

  List<dynamic> _withoutBlocked(List<dynamic> items) {
    return items.where((item) => !_isBlockedResult(item)).toList();
  }

  void _hideBlockedResults() {
    if (!mounted) return;
    setState(() {
      _searchResults = _withoutBlocked(_searchResults);
    });
  }

  void _onSearchChanged() {
    setState(() {});

    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      await BlockedSellers.instance.sync();
      final viewerUid = await AuthService.getCurrentUserId();
      final response = await ApiService.searchItems(query, viewerUid: viewerUid);

      if (!mounted) return;

      if (response['success'] == true) {
        final data = response['data'];
        setState(() {
          _searchResults = _withoutBlocked(data is List ? data : <dynamic>[]);
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _navigateToItem(String itemId) {
    if (widget.embeddedInShell && widget.onItemSelected != null) {
      widget.onItemSelected!(itemId);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeFeedScreen(initialItemId: itemId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    final isAr = lang == 'ar';
    final focused = _searchFocusNode.hasFocus;
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.embeddedInShell,
          leading: widget.embeddedInShell
              ? null
              : IconButton(
                  icon: Icon(Icons.arrow_back, color: cs.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
          titleSpacing: 0,
          title: Padding(
            // When embedded (no back button), pad both sides so the field
            // isn't flush with the screen edges.
            padding: widget.embeddedInShell
                ? const EdgeInsets.symmetric(horizontal: 16)
                : const EdgeInsetsDirectional.only(end: 16),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  if (value.trim().isNotEmpty) {
                    _performSearch(value.trim());
                  }
                },
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: focused
                      ? Colors.white
                      : const Color(0xFFF5F3FF),
                  hintText: isAr
                      ? 'ابحث عن المنتجات...'
                      : 'Search for products...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFA9A9B2),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  prefixIcon: Icon(
                    Iconsax.search_normal_1,
                    color: focused
                        ? const Color(0xFF5C33EA)
                        : const Color(0xFF8B7AF0),
                    size: 18,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.requestFocus();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          icon: const Icon(
                            Iconsax.close_circle,
                            color: Color(0xFFA9A9B2),
                            size: 18,
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF5C33EA),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          toolbarHeight: widget.embeddedInShell ? 52 : kToolbarHeight,
        ),
        body: _buildBody(isAr),
      ),
    );
  }

  Widget _buildBody(bool isAr) {
    if (!_hasSearched) {
      return _buildInitialEmptyState(isAr);
    }
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_searchResults.isEmpty) {
      return _buildNoResultsState(isAr);
    }
    return _buildResultsList(isAr);
  }

  Widget _buildInitialEmptyState(bool isAr) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.search_normal,
                size: 80,
                color: martIt.emptyIcon,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'ابحث عن ما تريد' : 'Search for what you want',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr
                  ? 'اكتب اسم المنتج في مربع البحث'
                  : 'Type product name in search box',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(bool isAr) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.emoji_sad,
                size: 56,
                color: martIt.emptyIcon,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isAr ? 'لا توجد نتائج' : 'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'جرب كلمة بحث مختلفة' : 'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        widget.embeddedInShell ? 100 : 24,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    final shimmerBase = context.appSurfaceVariant;
    final shimmerHighlight = context.appSurface;
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 110,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 14,
                    width: 72,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList(bool isAr) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        widget.embeddedInShell ? 100 : 24,
      ),
      itemCount: _searchResults.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Divider(
          height: 1,
          thickness: 1,
          color: context.appDivider,
        ),
      ),
      itemBuilder: (context, index) {
        return _buildSearchResultItem(_searchResults[index], isAr);
      },
    );
  }

  Map<String, dynamic>? _sellerMap(dynamic item) {
    if (item is! Map) return null;
    final seller = item['seller'];
    if (seller is Map) return Map<String, dynamic>.from(seller);
    return null;
  }

  Future<void> _reportSearchItem(dynamic item) {
    final seller = _sellerMap(item);
    return reportContent(
      context,
      targetType: 'product',
      itemId: item is Map ? item['id']?.toString() ?? '' : '',
      targetUid: seller?['uid']?.toString().isNotEmpty == true
          ? seller!['uid'].toString()
          : seller?['id']?.toString() ?? '',
      title: tr('moderation.report_listing'),
    );
  }

  Future<void> _blockSearchSeller(dynamic item) async {
    final seller = _sellerMap(item);
    if (seller == null) return;
    await blockAbusiveUser(
      context,
      blockedUid: seller['uid']?.toString().isNotEmpty == true
          ? seller['uid'].toString()
          : seller['id']?.toString() ?? '',
      name: seller['name']?.toString() ?? '',
      extraIds: [
        seller['id']?.toString() ?? '',
        seller['uid']?.toString() ?? '',
      ],
    );
  }

  Widget _buildSearchResultItem(dynamic item, bool isAr) {
    final cs = Theme.of(context).colorScheme;
    final martIt = context.martItColors;
    final itemId = item['id']?.toString() ?? '';
    final storeId =
        item['storeid']?.toString() ?? item['store_id']?.toString() ?? '1';
    final itemIdx = item['idx']?.toString();
    final preferredThumb = item['thumbnail']?.toString();
    final sellerName = item['seller']?['name']?.toString() ??
        (isAr ? 'بائع' : 'Seller');
    final title = isAr
        ? (item['name']?.toString() ?? '')
        : ((item['eng']?.toString().isNotEmpty == true)
            ? item['eng'].toString()
            : item['name']?.toString() ?? '');
    final thumbPlaceholder = martIt.receivedBubble;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToItem(itemId),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: cs.onSurface,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Iconsax.shop,
                          size: 14,
                          color: cs.primary.withValues(alpha: 0.75),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sellerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.primary.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _reportSearchItem(item),
                          icon: const Icon(Iconsax.flag, size: 16),
                          label: Text(tr('moderation.report')),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _blockSearchSeller(item),
                          icon: const Icon(Iconsax.user_remove, size: 16),
                          label: Text(tr('moderation.block')),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['price']} ${isAr ? 'ريال' : 'QAR'}',
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  color: thumbPlaceholder,
                  child: itemId.isNotEmpty
                      ? ItemThumbnailWidget(
                          storeId: storeId,
                          itemId: itemId,
                          itemIdx: itemIdx,
                          preferredUrl: preferredThumb,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          iconSize: 28,
                          placeholderColor: thumbPlaceholder,
                        )
                      : Icon(
                          Iconsax.image,
                          color: martIt.emptyIcon,
                          size: 28,
                        ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    BlockedSellers.instance.removeListener(_hideBlockedResults);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
