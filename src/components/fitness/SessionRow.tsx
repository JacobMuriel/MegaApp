/**
 * SessionRow — ported from FitnessLog/Views/History/SessionRow.swift
 * displayPrimaryMetric mirrors Swift SessionRow logic:
 *   treadmill  → avgSpeedMph (if set) or pace
 *   bike       → avgWatts
 *   outdoorRun → pace
 */

import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Session } from '../../store/fitnessStore';
import { formatDuration, formatDecimal } from '../../utils/format';
import { COLORS, SPACING, RADIUS, FONT_SIZE, FONT_WEIGHT } from '../../utils/constants';

const ACTIVITY_ICONS: Record<string, string> = {
  treadmill: '🏃',
  bike: '🚴',
  outdoorRun: '🌳',
};

const ACTIVITY_LABELS: Record<string, string> = {
  treadmill: 'Treadmill',
  bike: 'Bike',
  outdoorRun: 'Outdoor Run',
};

interface Props {
  session: Session;
  onPress: () => void;
}

export function SessionRow({ session, onPress }: Props): React.JSX.Element {

  return (
    <TouchableOpacity style={styles.row} onPress={onPress} activeOpacity={0.7}>
      <View style={styles.iconWrap}>
        <Text style={styles.icon}>{ACTIVITY_ICONS[session.activityType]}</Text>
      </View>
      <View style={styles.info}>
        <Text style={styles.label}>{ACTIVITY_LABELS[session.activityType]}</Text>
      </View>
      <View style={styles.stats}>
        <Text style={styles.duration}>{formatDuration(session.durationSeconds)}</Text>
        {session.distanceMiles != null && (
          <Text style={styles.distance}>
            {formatDecimal(session.distanceMiles, 2)} mi
          </Text>
        )}
        {session.calories != null && (
          <Text style={styles.calories}>{session.calories} cal</Text>
        )}
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  iconWrap: {
    width: 36,
    height: 36,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.primaryFaded,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  icon: { fontSize: 22 },
  info: { flex: 1 },
  label: { fontSize: FONT_SIZE.md, fontWeight: FONT_WEIGHT.semibold, color: COLORS.text },
  stats: { alignItems: 'flex-end' },
  duration: { fontSize: FONT_SIZE.md, fontWeight: FONT_WEIGHT.medium, color: COLORS.text },
  distance: { fontSize: FONT_SIZE.sm, color: COLORS.textSecondary },
  calories: { fontSize: FONT_SIZE.xs, color: COLORS.textMuted },
});
