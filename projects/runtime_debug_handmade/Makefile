.DEFAULT: main2.ice
ifdef tool
		silice-make.py -s main2.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@) -t $(tool)
else
		silice-make.py -s main2.ice -b $@ -p basic,pmod -o BUILD_$(subst :,_,$@)
endif

clean:
	rm -rf BUILD_*
