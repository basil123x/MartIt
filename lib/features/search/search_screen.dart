import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../home/tiktok_feed_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    } else {
      setState(() {
        _searchResults.clear();
        _hasSearched = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final response = await ApiService.searchItems(query);

      if (response['success'] == true) {
        setState(() {
          _searchResults = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _navigateToItem(String itemId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TikTokFeedScreen(initialItemId: itemId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث عن المنتجات...',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                prefixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(Iconsax.arrow_right, color: Colors.grey),
                ),
                suffixIcon: Visibility(
                  visible: _searchController.text != "" ? true : false,
                  child: IconButton(
                    onPressed: () => _searchController.clear(),
                    icon: Icon(Iconsax.close_square, color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),

            if (!_isLoading && _hasSearched && _searchResults.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.search_normal, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لا توجد نتائج',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'جرب البحث بكلمات مختلفة',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            if (!_isLoading && _searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final item = _searchResults[index];
                    return _buildSearchResultItem(item);
                  },
                ),
              ),

            if (!_hasSearched)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.search_normal, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'ابحث عن المنتجات',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'اكتب اسم المنتج الذي تبحث عنه',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    final storeId = (item['store_id'] ?? item['storeid'] ?? '4').toString();
    final itemId = item['id'].toString();
    final itemIdx = (item['idx'] ?? '').toString();
    final thumbnail =
        "https://martit.s3.ap-south-1.amazonaws.com/store_5/${itemIdx != '' ? itemIdx : itemId}/1.png";

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Color(0xFFB4D4F0).withAlpha(40),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: thumbnail != ''
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnail,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Iconsax.image, color: Colors.grey);
                    },
                  ),
                )
              : const Icon(Iconsax.image, color: Colors.grey),
        ),
        title: Text(
          item['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${item['price']} ريال',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'البائع: ${item['seller']['name']}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Iconsax.arrow_left_2, color: Colors.grey),
        onTap: () => _navigateToItem(item['id'].toString()),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
