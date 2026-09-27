import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/soundbox_service.dart';
import '../theme/ios_theme.dart';

class SoundboxScreen extends StatefulWidget {
  const SoundboxScreen({super.key});

  @override
  State<SoundboxScreen> createState() => _SoundboxScreenState();
}

class _SoundboxScreenState extends State<SoundboxScreen> {
  bool _isLoading = true;
  bool _isEnabled = true;
  String _selectedLanguage = SoundboxService.langTelugu;
  SoundboxTemplate _selectedTemplate = SoundboxTemplate.standard;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    SoundboxService.stop();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final enabled = await SoundboxService.isEnabled();
    final lang = await SoundboxService.getLanguage();
    final template = await SoundboxService.getTemplate();
    final rate = await SoundboxService.getSpeechRate();
    final pitch = await SoundboxService.getPitch();
    final volume = await SoundboxService.getVolume();

    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _selectedLanguage = lang;
        _selectedTemplate = template;
        _speechRate = rate;
        _pitch = pitch;
        _volume = volume;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEnabled(bool val) async {
    setState(() => _isEnabled = val);
    await SoundboxService.setEnabled(val);
  }

  Future<void> _setLanguage(String lang) async {
    setState(() => _selectedLanguage = lang);
    await SoundboxService.setLanguage(lang);
  }

  Future<void> _setTemplate(SoundboxTemplate template) async {
    setState(() => _selectedTemplate = template);
    await SoundboxService.setTemplate(template);
  }

  Future<void> _playSample() async {
    setState(() => _isPlaying = true);
    await SoundboxService.testAnnouncement(
      customLanguage: _selectedLanguage,
      customRate: _speechRate,
      customPitch: _pitch,
      customVolume: _volume,
      customTemplate: _selectedTemplate,
    );
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewSentence = SoundboxService.generateSentence(
      amount: '1000',
      sender: 'Roshan',
      bank: 'Union Bank',
      language: _selectedLanguage,
      template: _selectedTemplate,
    );

    return Scaffold(
      backgroundColor: IosColors.systemBackground,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // iOS Large Title Navigation Bar
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Soundbox',
              style: TextStyle(
                color: IosColors.label,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.6,
              ),
            ),
            backgroundColor: IosColors.systemBackground.withValues(alpha: 0.8),
            border: const Border(
              bottom: BorderSide(color: IosColors.separator, width: 0.5),
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _isPlaying ? null : _playSample,
              child: _isPlaying
                  ? const CupertinoActivityIndicator(radius: 10)
                  : const Icon(CupertinoIcons.play_circle, size: 22, color: IosColors.systemPurple),
            ),
          ),

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CupertinoActivityIndicator(radius: 14),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Master Soundbox Toggle
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: (_isEnabled ? IosColors.systemPurple : IosColors.tertiaryLabel)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isEnabled ? CupertinoIcons.speaker_2_fill : CupertinoIcons.speaker_slash_fill,
                              color: _isEnabled ? IosColors.systemPurple : IosColors.secondaryLabel,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voice Soundbox',
                                  style: TextStyle(
                                    color: IosColors.label,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Announce incoming payments aloud',
                                  style: TextStyle(
                                    color: IosColors.secondaryLabel,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CupertinoSwitch(
                            activeTrackColor: IosColors.systemPurple,
                            value: _isEnabled,
                            onChanged: _toggleEnabled,
                          ),
                        ],
                      ),
                    ),

                    // Section 2: Live Speech Preview Bubble
                    const IosSectionHeader(title: 'Live Preview'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.waveform, size: 16, color: IosColors.systemPurple),
                              const SizedBox(width: 8),
                              const Text(
                                'VOICE SENTENCE',
                                style: TextStyle(
                                  color: IosColors.secondaryLabel,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const Spacer(),
                              if (_isPlaying)
                                const Row(
                                  children: [
                                    CupertinoActivityIndicator(radius: 7),
                                    SizedBox(width: 6),
                                    Text('Speaking...', style: TextStyle(color: IosColors.systemPurple, fontSize: 12)),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: IosColors.tertiaryBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '"$previewSentence"',
                              style: const TextStyle(
                                color: IosColors.label,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: IosColors.systemPurple,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              borderRadius: BorderRadius.circular(10),
                              onPressed: _isPlaying ? null : _playSample,
                              child: _isPlaying
                                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(CupertinoIcons.play_fill, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          'Play Sample Alert',
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Section 3: Language Selection (iOS Inset List)
                    const IosSectionHeader(title: 'Voice Language'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _buildLanguageRow(
                            code: SoundboxService.langTelugu,
                            name: 'Telugu (తెలుగు)',
                            subtext: 'భారతీయ తెలుగు ఉచ్చారణ',
                          ),
                          const IosDivider(indent: 52),
                          _buildLanguageRow(
                            code: SoundboxService.langEnglishIndia,
                            name: 'English (India)',
                            subtext: 'Indian Accent English',
                          ),
                          const IosDivider(indent: 52),
                          _buildLanguageRow(
                            code: SoundboxService.langHindi,
                            name: 'Hindi (हिंदी)',
                            subtext: 'भारतीय हिंदी उच्चारण',
                          ),
                          const IosDivider(indent: 52),
                          _buildLanguageRow(
                            code: SoundboxService.langEnglishUS,
                            name: 'English (US)',
                            subtext: 'Standard US Accent',
                          ),
                        ],
                      ),
                    ),

                    // Section 4: Announcement Template
                    const IosSectionHeader(title: 'Announcement Style'),
                    IosGroupedCard(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          _buildTemplateRow(
                            template: SoundboxTemplate.standard,
                            title: 'Standard',
                            example: 'Union Bank: ₹1000 received',
                          ),
                          const IosDivider(indent: 52),
                          _buildTemplateRow(
                            template: SoundboxTemplate.short,
                            title: 'Short & Fast',
                            example: '₹1000 received',
                          ),
                          const IosDivider(indent: 52),
                          _buildTemplateRow(
                            template: SoundboxTemplate.detailed,
                            title: 'Detailed & Formal',
                            example: 'Union Bank account credited with Rs. 1000',
                          ),
                        ],
                      ),
                    ),

                    // Section 5: Voice Sliders
                    const IosSectionHeader(title: 'Speech Synthesizer Controls'),
                    IosGroupedCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Speech Rate
                          _buildSliderRow(
                            label: 'Speed',
                            valueStr: '${(_speechRate * 2).toStringAsFixed(1)}x',
                            child: CupertinoSlider(
                              value: _speechRate,
                              min: 0.2,
                              max: 1.0,
                              activeColor: IosColors.systemPurple,
                              onChanged: (val) {
                                setState(() => _speechRate = val);
                                SoundboxService.setSpeechRate(val);
                              },
                            ),
                          ),
                          const IosDivider(),
                          const SizedBox(height: 10),
                          // Pitch
                          _buildSliderRow(
                            label: 'Pitch',
                            valueStr: '${_pitch.toStringAsFixed(1)}x',
                            child: CupertinoSlider(
                              value: _pitch,
                              min: 0.5,
                              max: 1.8,
                              activeColor: IosColors.systemPurple,
                              onChanged: (val) {
                                setState(() => _pitch = val);
                                SoundboxService.setPitch(val);
                              },
                            ),
                          ),
                          const IosDivider(),
                          const SizedBox(height: 10),
                          // Volume
                          _buildSliderRow(
                            label: 'Volume',
                            valueStr: '${(_volume * 100).toInt()}%',
                            child: CupertinoSlider(
                              value: _volume,
                              min: 0.1,
                              max: 1.0,
                              activeColor: IosColors.systemPurple,
                              onChanged: (val) {
                                setState(() => _volume = val);
                                SoundboxService.setVolume(val);
                              },
                            ),
                          ),
                        ],
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

  Widget _buildLanguageRow({
    required String code,
    required String name,
    required String subtext,
  }) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () => _setLanguage(code),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(CupertinoIcons.checkmark_alt, size: 20, color: IosColors.systemPurple)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: IosColors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtext,
                    style: const TextStyle(
                      color: IosColors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateRow({
    required SoundboxTemplate template,
    required String title,
    required String example,
  }) {
    final isSelected = _selectedTemplate == template;
    return GestureDetector(
      onTap: () => _setTemplate(template),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(CupertinoIcons.checkmark_alt, size: 20, color: IosColors.systemPurple)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: IosColors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    example,
                    style: const TextStyle(
                      color: IosColors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueStr,
    required Widget child,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: IosColors.label,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              valueStr,
              style: const TextStyle(
                color: IosColors.secondaryLabel,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(
          width: double.infinity,
          child: child,
        ),
      ],
    );
  }
}
