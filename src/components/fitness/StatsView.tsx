/**
 * StatsView — ported from FitnessLog/Views/Stats/StatsView.swift
 * Uses distancePerMinutePoints (mi/min) — NOT pace (min/mi).
 * victory-native v41: CartesianChart + Line render-prop API.
 */

import React, { useMemo, useState } from 'react';
import { View, Text, ScrollView, StyleSheet, TouchableOpacity } from 'react-native';
import { CartesianChart, Line } from 'victory-native';
import { useFitnessStore } from '../../store/fitnessStore';
import { formatDecimal } from '../../utils/format';
import { COLORS, SPACING, RADIUS, FONT_SIZE, FONT_WEIGHT } from '../../utils/constants';

const COUNT_OPTIONS = [5, 10, 20, 50];

type ChartMode = 'runs' | 'bike';

export function StatsView(): React.JSX.Element {
  const sessions = useFitnessStore((s) => s.sessions);
  const [count, setCount] = useState(10);
  const [chartMode, setChartMode] = useState<ChartMode>('runs');

  // Outdoor run / treadmill sessions with distance
  const runSessions = useMemo(
    () =>
      sessions
        .filter(
          (s) =>
            (s.activityType === 'outdoorRun' || s.activityType === 'treadmill') &&
            s.distanceMiles != null &&
            s.distanceMiles > 0 &&
            s.durationSeconds > 0
        )
        .slice(0, count)
        .reverse(),
    [sessions, count]
  );

  // Bike sessions with distance
  const bikeSessions = useMemo(
    () =>
      sessions
        .filter(
          (s) =>
            s.activityType === 'bike' &&
            s.distanceMiles != null &&
            s.distanceMiles > 0 &&
            s.durationSeconds > 0
        )
        .slice(0, count)
        .reverse(),
    [sessions, count]
  );

  const activeSessions = chartMode === 'runs' ? runSessions : bikeSessions;

  // distancePerMinutePoints = mi/min — mirrors Swift StatsView
  const speedData = activeSessions.map((s, i) => ({
    x: i + 1,
    miPerMin: parseFloat(((s.distanceMiles! / s.durationSeconds) * 60).toFixed(4)),
  }));

  const distanceData = activeSessions.map((s, i) => ({
    x: i + 1,
    miles: parseFloat((s.distanceMiles ?? 0).toFixed(2)),
  }));

  // Totals across all sessions
  const totalDistance = sessions.reduce((sum, s) => sum + (s.distanceMiles ?? 0), 0);
  const totalCalories = sessions.reduce((sum, s) => sum + (s.calories ?? 0), 0);
  const totalSessions = sessions.length;

  // Activity breakdown
  const byType = sessions.reduce(
    (acc, s) => ({ ...acc, [s.activityType]: (acc[s.activityType] ?? 0) + 1 }),
    {} as Record<string, number>
  );

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Stats</Text>
        <Text style={styles.subtitle}>Your fitness overview</Text>
      </View>

      {/* Summary cards */}
      <View style={styles.cardRow}>
        <View style={styles.card}>
          <Text style={styles.cardValue}>{totalSessions}</Text>
          <Text style={styles.cardLabel}>Workouts</Text>
        </View>
        <View style={styles.card}>
          <Text style={styles.cardValue}>{formatDecimal(totalDistance, 1)}</Text>
          <Text style={styles.cardLabel}>Total mi</Text>
        </View>
        <View style={styles.card}>
          <Text style={styles.cardValue}>{totalCalories.toLocaleString()}</Text>
          <Text style={styles.cardLabel}>Calories</Text>
        </View>
      </View>

      {/* Activity breakdown */}
      <View style={styles.breakdownCard}>
        <Text style={styles.sectionHead}>Activity Breakdown</Text>
        <View style={styles.breakdownRow}>
          {[
            { key: 'treadmill', label: 'Treadmill', icon: '🏃' },
            { key: 'bike', label: 'Bike', icon: '🚴' },
            { key: 'outdoorRun', label: 'Outdoor', icon: '🌳' },
          ].map(({ key, label, icon }) => (
            <View key={key} style={styles.breakdownItem}>
              <Text style={styles.breakdownIcon}>{icon}</Text>
              <Text style={styles.breakdownCount}>{byType[key] ?? 0}</Text>
              <Text style={styles.breakdownLabel}>{label}</Text>
            </View>
          ))}
        </View>
      </View>

      {/* Runs / Bike toggle */}
      <View style={styles.modeRow}>
        {(['runs', 'bike'] as ChartMode[]).map((mode) => (
          <TouchableOpacity
            key={mode}
            onPress={() => setChartMode(mode)}
            style={[styles.modeBtn, chartMode === mode && styles.modeBtnActive]}
            activeOpacity={0.7}
          >
            <Text style={[styles.modeBtnText, chartMode === mode && styles.modeBtnTextActive]}>
              {mode === 'runs' ? '🏃 Runs' : '🚴 Bike'}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      {/* Last N sessions picker */}
      <View style={styles.pickerRow}>
        <Text style={styles.pickerLabel}>Last</Text>
        {COUNT_OPTIONS.map((n) => (
          <TouchableOpacity
            key={n}
            onPress={() => setCount(n)}
            style={[styles.pickerBtn, count === n && styles.pickerBtnActive]}
            activeOpacity={0.7}
          >
            <Text style={[styles.pickerBtnText, count === n && styles.pickerBtnTextActive]}>
              {n}
            </Text>
          </TouchableOpacity>
        ))}
        <Text style={styles.pickerLabel}>{chartMode === 'runs' ? 'runs' : 'rides'}</Text>
      </View>

      {activeSessions.length >= 2 ? (
        <>
          {/* Speed trend (mi/min) */}
          <View style={styles.chartSection}>
            <Text style={styles.chartTitle}>Speed Trend (mi/min)</Text>
            <CartesianChart
              data={speedData}
              xKey="x"
              yKeys={['miPerMin']}
              domainPadding={{ left: 20, right: 20, top: 20 }}
            >
              {({ points }) => (
                <Line
                  points={points.miPerMin}
                  color={COLORS.primary}
                  strokeWidth={2}
                />
              )}
            </CartesianChart>
          </View>

          {/* Distance trend */}
          <View style={styles.chartSection}>
            <Text style={styles.chartTitle}>Distance Trend (miles)</Text>
            <CartesianChart
              data={distanceData}
              xKey="x"
              yKeys={['miles']}
              domainPadding={{ left: 20, right: 20, top: 20 }}
            >
              {({ points }) => (
                <Line
                  points={points.miles}
                  color={COLORS.accent}
                  strokeWidth={2}
                />
              )}
            </CartesianChart>
          </View>
        </>
      ) : (
        <View style={styles.emptyChart}>
          <Text style={styles.emptyIcon}>📈</Text>
          <Text style={styles.emptyText}>
          Log at least 2 {chartMode === 'runs' ? 'runs' : 'rides'} to see trend charts.
        </Text>
        </View>
      )}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: COLORS.background },
  content: { padding: SPACING.md, paddingBottom: 80 },
  header: { marginBottom: SPACING.md },
  title: { fontSize: 26, fontWeight: '600' as const, color: '#2C2A24', lineHeight: 30 },
  subtitle: { fontSize: FONT_SIZE.xs, color: '#A09880', marginTop: 2 },

  cardRow: { flexDirection: 'row', gap: SPACING.sm, marginBottom: SPACING.md },
  card: {
    flex: 1,
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  cardValue: { fontSize: FONT_SIZE.xxl, fontWeight: FONT_WEIGHT.bold, color: COLORS.primary },
  cardLabel: { fontSize: FONT_SIZE.xs, color: COLORS.textSecondary, marginTop: 2 },

  breakdownCard: {
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  sectionHead: { fontSize: FONT_SIZE.sm, fontWeight: FONT_WEIGHT.semibold, color: COLORS.textSecondary, marginBottom: SPACING.sm },
  breakdownRow: { flexDirection: 'row', justifyContent: 'space-around' },
  breakdownItem: { alignItems: 'center', gap: 4 },
  breakdownIcon: { fontSize: 24 },
  breakdownCount: { fontSize: FONT_SIZE.xl, fontWeight: FONT_WEIGHT.bold, color: COLORS.primary },
  breakdownLabel: { fontSize: FONT_SIZE.xs, color: COLORS.textSecondary },

  modeRow: {
    flexDirection: 'row',
    gap: SPACING.sm,
    marginBottom: SPACING.sm,
  },
  modeBtn: {
    flex: 1,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border,
    alignItems: 'center',
    backgroundColor: COLORS.surface,
  },
  modeBtnActive: { backgroundColor: COLORS.primary, borderColor: COLORS.primary },
  modeBtnText: { fontSize: FONT_SIZE.sm, fontWeight: FONT_WEIGHT.medium, color: COLORS.textSecondary },
  modeBtnTextActive: { color: COLORS.textInverse },

  pickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.xs,
    marginBottom: SPACING.md,
  },
  pickerLabel: { fontSize: FONT_SIZE.sm, color: COLORS.textSecondary },
  pickerBtn: {
    paddingHorizontal: SPACING.sm,
    paddingVertical: 4,
    borderRadius: RADIUS.full,
    borderWidth: 1,
    borderColor: COLORS.border,
  },
  pickerBtnActive: { backgroundColor: COLORS.primary, borderColor: COLORS.primary },
  pickerBtnText: { fontSize: FONT_SIZE.sm, color: COLORS.textSecondary },
  pickerBtnTextActive: { color: COLORS.textInverse, fontWeight: FONT_WEIGHT.medium },

  chartSection: {
    backgroundColor: COLORS.surface,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    marginBottom: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border,
    height: 240,
  },
  chartTitle: { fontSize: FONT_SIZE.md, fontWeight: FONT_WEIGHT.semibold, color: COLORS.text, marginBottom: SPACING.sm },

  emptyChart: { alignItems: 'center', paddingVertical: SPACING.xxl },
  emptyIcon: { fontSize: 40, marginBottom: 12 },
  emptyText: { color: COLORS.textMuted, textAlign: 'center', fontSize: FONT_SIZE.md },
});
