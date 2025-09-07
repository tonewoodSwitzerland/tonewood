import 'package:flutter/material.dart';
import '../../../services/icon_helper.dart';
import '../models/roundwood_models.dart';
import '../constants/roundwood_constants.dart';
import 'package:intl/intl.dart';

class RoundwoodListItem extends StatelessWidget {
  final RoundwoodItem item;
  final VoidCallback onTap;
  final bool isDesktopLayout;

  const RoundwoodListItem({
    Key? key,
    required this.item,
    required this.onTap,
    required this.isDesktopLayout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: isDesktopLayout ? _buildDesktopLayout(theme) : _buildMobileLayout(theme),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    return Row(
      children: [
        _buildLeadingSection(theme),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleSection(theme),
              const SizedBox(height: 8),
              _buildDetailsSection(theme),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetadataSection(theme),
        ),
        const SizedBox(width: 16),
        _buildTrailingSection(theme),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLeadingSection(theme),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleSection(theme),
              const SizedBox(height: 8),
              _buildDetailsSection(theme),
              const SizedBox(height: 8),
              _buildMetadataSection(theme),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildTrailingSection(theme),
      ],
    );
  }

  Widget _buildLeadingSection(ThemeData theme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: RoundwoodColors.getWoodColor(item.woodName, 0).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          item.internalNumber,
          style: theme.textTheme.titleMedium?.copyWith(
            color: RoundwoodColors.getWoodColor(item.woodName, 0),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(ThemeData theme) {
    return Row(
      children: [
        Text(
          item.woodName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (item.isMoonwood) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Mondholz',
            child: getAdaptiveIcon(iconName: 'nightlight', defaultIcon:
              Icons.nightlight,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsSection(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: RoundwoodColors.getQualityColor(item.qualityName, 0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              getAdaptiveIcon(iconName:'star', defaultIcon:
                Icons.star,
                size: 12,
                color: RoundwoodColors.getQualityColor(item.qualityName, 0),
              ),
              const SizedBox(width: 4),
              Text(
                item.qualityName,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RoundwoodColors.getQualityColor(item.qualityName, 0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (item.origin != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                getAdaptiveIcon(iconName: 'location_on', defaultIcon:
                  Icons.location_on,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  item.origin!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetadataSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.purpose != null) ...[
          Row(
            children: [
              getAdaptiveIcon(iconName: 'info', defaultIcon:
                Icons.info,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.purpose!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (isDesktopLayout && item.remarks?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              getAdaptiveIcon(iconName:'notes', defaultIcon:
                Icons.notes,
                size: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.remarks!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrailingSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${item.volume.toStringAsFixed(2)} m³',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('dd.MM.yyyy').format(item.timestamp),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}